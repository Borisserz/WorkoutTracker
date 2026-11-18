

import Foundation
import OSLog
import SwiftData
import AudioToolbox
import WidgetKit
import WatchConnectivity
internal import SwiftUI

@Observable
@MainActor
final class WorkoutService {

    public private(set) var aiLogicService: AILogicService

    private let workoutStore: WorkoutStoreProtocol
    private let analyticsService: AnalyticsService
    private let exerciseCatalogService: ExerciseCatalogService
    private let widgetSyncService: WidgetSyncService
    private let notificationManager: NotificationManager
    private let progressManager: ProgressManager

    private let appState: AppStateManager
    private let liveActivityManager: LiveActivityManager
    /// Serializes create/start so two awaits cannot both pass `hasActiveWorkout` (TOCTOU).
    private var startInFlight = false
    /// Tracks the Watch workout UUID currently being created so simultaneous deliveries dedup cleanly.
    private var inFlightWatchStartID: UUID?
    /// Blocks new starts during finish snackbar undo window (endTime set but session not committed).
    private var finishTransitionDepth = 0
    /// After Watch `canStartWorkout` allowed=true — block phone Hub starts until Watch `.startWorkout` or TTL.
    private var watchStartReservedUntil: Date?
    /// Token for LiveWorkoutSyncEvent; `@ObservationIgnored` and `nonisolated(unsafe)` so `deinit` can unregister.
    @ObservationIgnored nonisolated(unsafe) private var liveSyncObserver: (any NSObjectProtocol)?
    @ObservationIgnored nonisolated private let watchNotificationCenter: NotificationCenter
    @ObservationIgnored nonisolated(unsafe) private var watchSyncContinuation: AsyncStream<LiveSyncPayload>.Continuation?
    @ObservationIgnored nonisolated(unsafe) private var watchSyncConsumerTask: Task<Void, Never>?

    var isFinishTransitionPending: Bool { finishTransitionDepth > 0 }
    /// Sync gate for UI (History/Hub) — covers in-flight start, finish-undo, and Watch start reservation.
    var isStartBlocked: Bool {
        startInFlight
            || finishTransitionDepth > 0
            || WatchSessionPolicy.isWatchStartReservationActive(until: watchStartReservedUntil)
    }

    var finishedSessionRevision: Int = 0

    func beginFinishTransition() {
        finishTransitionDepth += 1
        if finishTransitionDepth == 1 {
            finishedSessionRevision += 1
        }
    }

    func endFinishTransition() {
        finishTransitionDepth = max(0, finishTransitionDepth - 1)
        if finishTransitionDepth == 0 {
            finishedSessionRevision += 1
        }
    }

    func noteWatchStartReserved(seconds: TimeInterval = WatchSessionPolicy.watchStartReservationSeconds) {
        watchStartReservedUntil = Date().addingTimeInterval(seconds)
    }

    func clearWatchStartReservation() {
        watchStartReservedUntil = nil
    }

    deinit {
        if let liveSyncObserver {
            watchNotificationCenter.removeObserver(liveSyncObserver)
        }
        watchSyncContinuation?.finish()
        watchSyncConsumerTask?.cancel()
    }

    init(workoutStore: WorkoutStoreProtocol,
         analyticsService: AnalyticsService,
         exerciseCatalogService: ExerciseCatalogService,
         widgetSyncService: WidgetSyncService,
         aiLogicService: AILogicService,
         notificationManager: NotificationManager,
         progressManager: ProgressManager,
         appState: AppStateManager,
         liveActivityManager: LiveActivityManager,
         watchNotificationCenter: NotificationCenter = .default) {

        self.workoutStore = workoutStore
        self.analyticsService = analyticsService
        self.exerciseCatalogService = exerciseCatalogService
        self.widgetSyncService = widgetSyncService
        self.aiLogicService = aiLogicService
        self.notificationManager = notificationManager
        self.progressManager = progressManager
        self.appState = appState
        self.liveActivityManager = liveActivityManager
        self.watchNotificationCenter = watchNotificationCenter

        var capturedContinuation: AsyncStream<LiveSyncPayload>.Continuation?
        let stream = AsyncStream<LiveSyncPayload> { continuation in
            capturedContinuation = continuation
        }
        self.watchSyncContinuation = capturedContinuation

        let container = analyticsService.modelContainer
        self.watchSyncConsumerTask = Task.detached { [weak self] in
            for await payload in stream {
                guard !Task.isCancelled, let self else { break }
                await self.handleSerializedWatchPayload(payload, container: container)
            }
        }

        liveSyncObserver = watchNotificationCenter.addObserver(forName: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, queue: .main) { [weak self] notification in
            guard let payloadDict = notification.userInfo?["payload"],
                  let payload = payloadDict as? LiveSyncPayload else { return }
            self?.watchSyncContinuation?.yield(payload)
        }
    }

    nonisolated private func handleSerializedWatchPayload(_ payload: LiveSyncPayload, container: ModelContainer) async {
                let bgContext = ModelContext(container)
                let workoutUUID = UUID(uuidString: payload.workoutID)

                switch payload.action {
                case .startWorkout:
                    guard let uuid = workoutUUID else { return }
                    // Deduplicate live + guaranteed Watch deliveries for the same session ID.
                    let existingDesc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let existingSameID = try? bgContext.fetch(existingDesc).first {
                        let pid = existingSameID.persistentModelID
                        await MainActor.run {
                            self.clearWatchStartReservation()
                            self.appState.returnToActiveWorkoutId = pid
                        }
                        return
                    }
                    // Share phone start mutex so Watch cannot race createWorkout / startGeneratedWorkout.
                    let claimed = await MainActor.run { () -> Bool in
                        if self.startInFlight {
                            if self.inFlightWatchStartID == uuid {
                                return false
                            }
                            self.appState.showError(
                                title: String(localized: "Workout in progress"),
                                message: String(localized: "Finish or delete the current workout before starting another.")
                            )
                            return false
                        }
                        if self.finishTransitionDepth > 0 {
                            self.appState.showError(
                                title: String(localized: "Workout in progress"),
                                message: String(localized: "Finish or delete the current workout before starting another.")
                            )
                            return false
                        }
                        self.startInFlight = true
                        self.inFlightWatchStartID = uuid
                        self.clearWatchStartReservation()
                        return true
                    }
                    guard claimed else { return }
                    defer {
                        Task { @MainActor in
                            self.startInFlight = false
                            if self.inFlightWatchStartID == uuid {
                                self.inFlightWatchStartID = nil
                            }
                        }
                    }
                    // Heal stale (>12h) / multi-active before accepting Watch start — same path as Hub.
                    if await self.hasActiveWorkout() {
                        if let existing = await self.fetchLatestWorkout() {
                            let existingID = existing.persistentModelID
                            await MainActor.run {
                                self.appState.returnToActiveWorkoutId = existingID
                                self.appState.showError(
                                    title: String(localized: "Workout in progress"),
                                    message: String(localized: "Finish or delete the current workout before starting another.")
                                )
                            }
                        }
                        return
                    }
                    await MainActor.run {
                        TrackingManager.shared.track(.watchWorkoutStarted)
                    }
                    let newWorkout = Workout(id: uuid, title: payload.workoutTitle ?? "Watch Workout", date: Date(), exercises: [])
                    newWorkout.icon = "applewatch"
                    bgContext.insert(newWorkout)

                    if let exercisesDTO = payload.exercises {
                        for dto in exercisesDTO {
                            let exercise = Exercise(from: dto)
                            bgContext.insert(exercise)
                            for set in exercise.setsList { bgContext.insert(set) }
                            for sub in exercise.subExercises {
                                bgContext.insert(sub)
                                for set in sub.setsList { bgContext.insert(set) }
                            }
                            exercise.workout = newWorkout
                            newWorkout.exercises.append(exercise)
                        }
                    }
                    do {
                        try bgContext.save()
                    } catch {
                        await MainActor.run {
                            self.appState.showError(
                                title: String(localized: "Watch sync failed"),
                                message: String(localized: "Could not save the Watch workout on iPhone.")
                            )
                        }
                        return
                    }

                    let newTitle = newWorkout.title
                    let newID = newWorkout.persistentModelID
                    await MainActor.run {
                        self.liveActivityManager.startWorkoutActivity(title: newTitle)
                        self.appState.returnToActiveWorkoutId = newID
                    }

                case .addExercise:
                    guard let uuid = workoutUUID, let exName = payload.exerciseName else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first {
                        let newEx = Exercise(name: exName, muscleGroup: "Mixed", type: .strength, sets: 3, reps: 10, weight: 0)
                        bgContext.insert(newEx)
                        for set in newEx.setsList { bgContext.insert(set) }
                        newEx.workout = workout
                        workout.exercises.append(newEx)
                        do { try bgContext.save() } catch {
                            await MainActor.run {
                                self.appState.showError(
                                    title: String(localized: "Watch sync failed"),
                                    message: error.localizedDescription
                                )
                            }
                        }
                    }

                case .removeExercise:
                    guard let uuid = workoutUUID, let exName = payload.exerciseName else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first,
                       let idx = workout.exercises.firstIndex(where: { $0.name == exName }) {
                        let removed = workout.exercises.remove(at: idx)
                        bgContext.delete(removed)
                        try? bgContext.save()
                    }

                case .addSet:
                    guard let uuid = workoutUUID, let exName = payload.exerciseName, let setIndex = payload.setIndex else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first,
                       let exercise = workout.exercises.first(where: { $0.name == exName }),
                       !exercise.setsList.contains(where: { $0.index == setIndex }) {
                        let newSet = WorkoutSet(index: setIndex, weight: nil, reps: nil, isCompleted: false, type: .normal)
                        bgContext.insert(newSet)
                        newSet.exercise = exercise
                        exercise.setsList.append(newSet)
                        try? bgContext.save()
                    }

                case .removeSet:
                    guard let uuid = workoutUUID, let exName = payload.exerciseName, let setIndex = payload.setIndex else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first,
                       let exercise = workout.exercises.first(where: { $0.name == exName }) {
                        let toDelete = exercise.setsList.filter { $0.index == setIndex }
                        for s in toDelete {
                            exercise.setsList.removeAll { $0.persistentModelID == s.persistentModelID }
                            bgContext.delete(s)
                        }
                        let sorted = exercise.setsList.sorted { $0.index < $1.index }
                        for (offset, s) in sorted.enumerated() { s.index = offset + 1 }
                        try? bgContext.save()
                    }

                case .logSet:
                    guard let uuid = workoutUUID, let exName = payload.exerciseName, let setIndex = payload.setIndex else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first,
                       let exercise = workout.exercises.first(where: { $0.name == exName }) {
                        if let setToUpdate = exercise.setsList.first(where: { $0.index == setIndex }) {
                            setToUpdate.weight = payload.weight
                            setToUpdate.reps = payload.reps
                            setToUpdate.isCompleted = payload.isCompleted ?? true
                        } else {
                            let newSet = WorkoutSet(
                                index: setIndex,
                                weight: payload.weight,
                                reps: payload.reps,
                                isCompleted: payload.isCompleted ?? true,
                                type: .normal
                            )
                            bgContext.insert(newSet)
                            newSet.exercise = exercise
                            exercise.setsList.append(newSet)
                        }
                        do { try bgContext.save() } catch {
                            await MainActor.run {
                                self.appState.showError(
                                    title: String(localized: "Watch sync failed"),
                                    message: error.localizedDescription
                                )
                            }
                        }
                    }

                case .updateEffort:
                    guard let uuid = workoutUUID, let exName = payload.exerciseName, let effort = payload.effort else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first,
                       let exercise = workout.exercises.first(where: { $0.name == exName }) {
                        exercise.effort = effort
                        exercise.isCompleted = true
                        do { try bgContext.save() } catch {
                            await MainActor.run {
                                self.appState.showError(
                                    title: String(localized: "Watch sync failed"),
                                    message: error.localizedDescription
                                )
                            }
                        }
                    }

                case .finishWorkout:
                    guard let uuid = workoutUUID else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first {
                        let pid = workout.persistentModelID
                        await MainActor.run {
                            let mainContext = container.mainContext
                            if let mainWorkout = mainContext.model(for: pid) as? Workout {
                                Task {
                                    await self.processCompletedWorkout(
                                        mainWorkout,
                                        mirrorToHealthKit: payload.healthKitSavedOnWatch != true
                                    )
                                }
                                self.appState.returnToActiveWorkoutId = nil
                            }
                        }
                    }

                case .saveToHistory:
                    guard let uuid = workoutUUID else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    let workout: Workout
                    if let existing = try? bgContext.fetch(desc).first {
                        workout = existing
                    } else {
                        let created = Workout(
                            id: uuid,
                            title: payload.workoutTitle ?? "Watch Workout",
                            date: Date().addingTimeInterval(-Double(payload.durationSeconds ?? 0)),
                            exercises: []
                        )
                        created.icon = "applewatch"
                        bgContext.insert(created)
                        workout = created
                    }

                    if let dDuration = payload.durationSeconds, dDuration > 0 {
                        workout.durationSeconds = dDuration
                    }

                    if let exercisesDTO = payload.exercises {
                        for old in workout.exercises { bgContext.delete(old) }
                        workout.exercises.removeAll()
                        for dto in exercisesDTO {
                            let ex = Exercise(from: dto)
                            bgContext.insert(ex)
                            for set in ex.setsList { bgContext.insert(set) }
                            for sub in ex.subExercises {
                                bgContext.insert(sub)
                                for set in sub.setsList { bgContext.insert(set) }
                            }
                            ex.workout = workout
                            workout.exercises.append(ex)
                        }
                    }
                    try? bgContext.save()
                    let itemsCount = workout.exercises.count
                    let pid = workout.persistentModelID
                    await MainActor.run {
                        TrackingManager.shared.track(.watchSyncCompleted(success: true, itemsSynced: itemsCount))
                        let mainContext = container.mainContext
                        if let mainWorkout = mainContext.model(for: pid) as? Workout {
                            Task {
                                await self.processCompletedWorkout(
                                    mainWorkout,
                                    mirrorToHealthKit: payload.healthKitSavedOnWatch != true
                                )
                            }
                            self.appState.returnToActiveWorkoutId = nil
                        }
                    }

                case .discardWorkout:
                    guard let uuid = workoutUUID else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first {
                        let pid = workout.persistentModelID
                        await MainActor.run {
                            let mainContext = container.mainContext
                            if let mainWorkout = mainContext.model(for: pid) as? Workout {
                                Task { await self.deleteWorkout(mainWorkout) }
                            }
                        }
                    }

                case .requestActiveState, .syncFullState, .updateHeartRate, .clearLocalData:
                    break
                }
    }

    func syncPresetsWithWatch(presets: [WorkoutPreset]) {
        let dtos = presets.map { $0.toDTO() }
        if let data = try? JSONEncoder().encode(dtos) {
            WCSession.default.sendMessage(["presetsBatch": data], replyHandler: nil)
        }
    }

    func fetchLatestWorkout() async -> Workout? {
        do {
            if let id = try await workoutStore.fetchLatestWorkoutID() {
                let context = analyticsService.modelContainer.mainContext
                return context.model(for: id) as? Workout
            }
            return nil
        } catch {
            appState.showError(title: "Error", message: "Failed to fetch latest workout")
            return nil
        }
    }

    func createWorkout(title: String, presetID: PersistentIdentifier?, isAIGenerated: Bool, exerciseCount: Int = 0, estimatedDuration: Int = 0) async -> PersistentIdentifier? {
        if isStartBlocked {
            appState.showError(
                title: String(localized: "Workout in progress"),
                message: String(localized: "Finish or delete the current workout before starting another.")
            )
            return nil
        }
        // Claim the start lock before any await — otherwise two MainActor tasks both pass the check.
        startInFlight = true
        clearWatchStartReservation()
        defer { startInFlight = false }
        let alreadyActive = await hasActiveWorkout()
        if alreadyActive {
            appState.showError(
                title: String(localized: "Workout in progress"),
                message: String(localized: "Finish or delete the current workout before starting another.")
            )
            return nil
        }
        do {
            try? await HealthKitManager.shared.requestAuthorization()
            let id = try await workoutStore.createWorkout(title: title, fromPresetID: presetID, isAIGenerated: isAIGenerated)
            
            let source = isAIGenerated ? "ai_builder" : (presetID != nil ? "template" : "manual")
            TrackingManager.shared.track(.workoutStarted(source: source, exerciseCount: exerciseCount, estimatedDuration: estimatedDuration))
            
            liveActivityManager.startWorkoutActivity(title: title)
            return id
        } catch {
            appState.showError(title: String(localized: "Error"), message: error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    func startGeneratedWorkout(_ generated: GeneratedWorkoutDTO, source: String = "ai_builder") async -> PersistentIdentifier? {
        if isStartBlocked {
            appState.showError(
                title: String(localized: "Workout in progress"),
                message: String(localized: "Finish or delete the current workout before starting another.")
            )
            return nil
        }
        startInFlight = true
        clearWatchStartReservation()
        defer { startInFlight = false }
        let alreadyActive = await hasActiveWorkout()
        if alreadyActive {
            appState.showError(
                title: String(localized: "Workout in progress"),
                message: String(localized: "Finish or delete the current workout before starting another.")
            )
            return nil
        }
        do {
            try? await HealthKitManager.shared.requestAuthorization()
            let id = try await workoutStore.createWorkoutFromAI(generated: generated)
            let estimated = generated.exercises.reduce(0) { partial, ex in
                partial + max(0, ex.sets) * max(45, ex.restSeconds ?? 90)
            } / 60
            TrackingManager.shared.track(.workoutStarted(
                source: source,
                exerciseCount: generated.exercises.count,
                estimatedDuration: estimated
            ))
            liveActivityManager.startWorkoutActivity(title: generated.title)
            return id
        } catch {
            appState.showError(
                title: String(localized: "Save Failed"),
                message: String(localized: "Failed to save generated workout: \(error.localizedDescription)")
            )
            return nil
        }
    }

    func hasActiveWorkout() async -> Bool {
        if finishTransitionDepth > 0 { return true }
        do {
            let activeIDs = try await workoutStore.findActiveWorkoutsAndCleanup()
            return !activeIDs.isEmpty
        } catch {
            // Fail closed: unknown store state must not allow a second active session.
            AppLog.session.error("Error checking for active workouts: \(error.localizedDescription, privacy: .public)")
            appState.showError(
                title: String(localized: "Workout in progress"),
                message: String(localized: "Could not verify active workouts. Try again in a moment.")
            )
            return true
        }
    }

    func addSet(to exercise: Exercise, index: Int, weight: Double?, reps: Int?, distance: Double?, time: Int?, type: SetType, isCompleted: Bool) async {
        do {
            try await workoutStore.addSet(toExerciseID: exercise.persistentModelID, index: index, weight: weight, reps: reps, distance: distance, time: time, type: type, isCompleted: isCompleted)
        } catch {
            appState.showError(title: "Error", message: "Could not add set: \(error.localizedDescription)")
        }
    }

    func deleteSet(_ set: WorkoutSet, from exercise: Exercise) async {
        do {
            try await workoutStore.deleteSet(setID: set.persistentModelID, fromExerciseID: exercise.persistentModelID)
        } catch {
            appState.showError(title: "Error", message: "Could not delete set: \(error.localizedDescription)")
        }
    }

    func deleteSets(_ sets: [WorkoutSet], from exercise: Exercise) async {
        let ids = sets.map { $0.persistentModelID }
        do {
            try await workoutStore.deleteSets(setIDs: ids, fromExerciseID: exercise.persistentModelID)
        } catch {
            appState.showError(title: "Error", message: "Could not batch delete sets: \(error.localizedDescription)")
        }
    }

    func removeSubExercise(_ subExercise: Exercise, from superset: Exercise) async {
        do {
            try await workoutStore.removeSubExercise(subID: subExercise.persistentModelID, fromSupersetID: superset.persistentModelID)
        } catch {
            appState.showError(title: "Error", message: "Could not remove sub-exercise: \(error.localizedDescription)")
        }
    }

    func removeExercise(_ exercise: Exercise, from workout: Workout) async {
        do {
            try await workoutStore.removeExercise(exerciseID: exercise.persistentModelID, fromWorkoutID: workout.persistentModelID)
        } catch {
            appState.showError(title: "Error", message: "Could not remove exercise: \(error.localizedDescription)")
        }
    }

    func updateWorkoutFavoriteStatus(workout: Workout, isFavorite: Bool) async {
        do {
            try await workoutStore.updateWorkoutFavoriteStatus(workoutID: workout.persistentModelID, isFavorite: isFavorite)
        } catch {
            appState.showError(title: "Error", message: "Could not update workout favorite status: \(error.localizedDescription)")
        }
    }

    func updateExerciseEffort(exercise: Exercise, newEffort: Int) async {
        do {
            try await workoutStore.updateExercise(exerciseID: exercise.persistentModelID, newEffort: newEffort)
        } catch {
            appState.showError(title: "Error", message: "Could not update exercise effort: \(error.localizedDescription)")
        }
    }

    func updateExerciseCompleted(exerciseID: PersistentIdentifier, isCompleted: Bool) async {
        do {
            try await workoutStore.updateExercise(exerciseID: exerciseID, isCompleted: isCompleted)
        } catch {
            appState.showError(title: "Error", message: "Could not update exercise: \(error.localizedDescription)")
        }
    }

    func updateSet(setID: PersistentIdentifier, reps: Int? = nil, weight: Double? = nil, time: Int? = nil, distance: Double? = nil, type: SetType? = nil, isCompleted: Bool? = nil) async {
        do {
            try await workoutStore.updateSet(setID: setID, reps: reps, weight: weight, time: time, distance: distance, type: type, isCompleted: isCompleted)
        } catch {
            appState.showError(title: "Error", message: "Could not update set: \(error.localizedDescription)")
        }
    }

    func updateWorkoutChatHistory(workout: Workout, history: [AIChatMessage]) async {
        do {
            try await workoutStore.updateWorkoutChatHistory(workoutID: workout.persistentModelID, history: history)
        } catch {
            appState.showError(title: "Error", message: "Could not update AI chat history: \(error.localizedDescription)")
        }
    }

    func processCompletedWorkout(_ workout: Workout, mirrorToHealthKit: Bool = true) async {
            defer { liveActivityManager.stopAllActivities() }
            do {
                try await workoutStore.processCompletedWorkout(workoutID: workout.persistentModelID)
                await updateWidgetData()

                guard mirrorToHealthKit else { return }

                let wTitle = workout.title
                let wStart = workout.date
                let wEnd = workout.endTime ?? Date()
                let wDuration = workout.durationSeconds > 0 ? workout.durationSeconds : Int(wEnd.timeIntervalSince(wStart))

                let userWeight = BodyMetricStore.weightKilograms() ?? 0
                let burnedCalories = CalorieCalculator.calculate(for: workout, userWeight: userWeight)
                let wDistance = max(workout.computedCardioDistanceMeters, workout.totalCardioDistance)

                Task.detached {
                    do {
                        try await HealthKitManager.shared.requestAuthorization()
                        try await HealthKitManager.shared.saveWorkout(
                            title: wTitle,
                            startDate: wStart,
                            endDate: wEnd,
                            durationSeconds: wDuration,
                            calories: burnedCalories,
                            distanceMeters: wDistance
                        )
                    } catch {
                        AppLog.session.error("⚠️ Failed to sync workout to HealthKit: \(error.localizedDescription, privacy: .public)")
                    }
                }
            } catch {
                appState.showError(title: "Process Failed", message: "Could not process completed workout: \(error.localizedDescription)")
            }
        }
    func stopLiveActivity() {
        liveActivityManager.stopAllActivities()
    }

    func deleteWorkout(_ workout: Workout) async {
        let wasActiveSession = workout.endTime == nil
        let workoutUUIDString = workout.id.uuidString
        do {
            try await workoutStore.deleteWorkout(id: workout.id)
            if wasActiveSession {
                PhoneWatchManager.shared.sendDiscardWorkoutToWatch(workoutID: workoutUUIDString)
                await stopLiveActivityIfNoActiveSession()
            }
            await updateWidgetData()
        } catch {
            appState.showError(title: "Delete Failed", message: "Could not delete workout: \(error.localizedDescription)")
        }
    }

    func deleteWorkout(id: UUID) async {
        let mainCtx = analyticsService.modelContainer.mainContext
        let checkDesc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id })
        let wasActiveSession = ((try? mainCtx.fetch(checkDesc))?.first?.endTime) == nil
        do {
            try await workoutStore.deleteWorkout(id: id)
            if wasActiveSession {
                PhoneWatchManager.shared.sendDiscardWorkoutToWatch(workoutID: id.uuidString)
            }
            // Never blanket-stop LA: History may delete a finished row while another session is live.
            await stopLiveActivityIfNoActiveSession()
            await updateWidgetData()
        } catch {
            appState.showError(title: "Delete Failed", message: "Could not delete workout: \(error.localizedDescription)")
        }
    }

    private func stopLiveActivityIfNoActiveSession() async {
        do {
            let activeIDs = try await workoutStore.findActiveWorkoutsAndCleanup()
            if activeIDs.isEmpty && !isFinishTransitionPending {
                stopLiveActivity()
            }
        } catch {
            // Fail closed for LA: if we cannot verify actives, leave Island alone rather than killing a live session.
        }
    }

    func cleanupAndFindActiveWorkouts() async {
        do {
            let activeIDs = try await workoutStore.findActiveWorkoutsAndCleanup()
            if activeIDs.isEmpty { stopLiveActivity() }
        } catch {
            AppLog.session.error("Cleanup failed: \(error.localizedDescription)")
        }
    }

    func applyAIAdjustment(_ adjustment: InWorkoutResponseDTO, to workout: Workout) async {
        do {
            try await workoutStore.applyAIAdjustment(adjustment, workoutID: workout.persistentModelID)
        } catch {
            appState.showError(title: "AI Update Failed", message: "Could not apply AI recommendations: \(error.localizedDescription)")
        }
    }

    func checkAndGenerateDefaultPresets() async {
        do {
            try await exerciseCatalogService.checkAndGenerateDefaultPresets()
        } catch {
            AppLog.session.error("Failed to generate default presets: \(error.localizedDescription)")
        }
    }

    func updateWidgetData() async {
        await widgetSyncService.updateWidgetData()
    }

    func swapExercise(old: Exercise, new: Exercise, workout: Workout) async {
        do {
            let newDTO = new.toDTO()
            try await workoutStore.swapExercise(oldID: old.persistentModelID, newExerciseDTO: newDTO, inWorkoutID: workout.persistentModelID)
        } catch {
            appState.showError(title: "Swap Failed", message: "Could not swap exercise: \(error.localizedDescription)")
        }
    }

    func applySmartAction(_ proposal: SmartActionDTO, to workout: Workout) async {
        do {
            try await workoutStore.applySmartAction(
                proposal: proposal,
                inWorkoutID: workout.persistentModelID,
                weightUnit: UnitsManager.shared.weightUnit
            )
            await updateWidgetData()
        } catch {
            appState.showError(title: "Database Error", message: "Failed to apply AI changes.")
        }
    }
}
