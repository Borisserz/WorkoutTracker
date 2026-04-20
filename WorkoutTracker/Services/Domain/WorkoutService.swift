// ============================================================
// FILE: WorkoutTracker/Services/Domain/WorkoutService.swift
// ============================================================

import Foundation
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

    init(workoutStore: WorkoutStoreProtocol,
         analyticsService: AnalyticsService,
         exerciseCatalogService: ExerciseCatalogService,
         widgetSyncService: WidgetSyncService,
         aiLogicService: AILogicService,
         notificationManager: NotificationManager,
         progressManager: ProgressManager,
         appState: AppStateManager,
         liveActivityManager: LiveActivityManager) {
        
        self.workoutStore = workoutStore
        self.analyticsService = analyticsService
        self.exerciseCatalogService = exerciseCatalogService
        self.widgetSyncService = widgetSyncService
        self.aiLogicService = aiLogicService
        self.notificationManager = notificationManager
        self.progressManager = progressManager
        self.appState = appState
        self.liveActivityManager = liveActivityManager
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("LiveWorkoutSyncEvent"), object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let payloadDict = notification.userInfo?["payload"],
                  let payload = payloadDict as? LiveSyncPayload else { return }
            
            Task { @MainActor in
                let bgContext = ModelContext(self.analyticsService.modelContainer)
                let workoutUUID = UUID(uuidString: payload.workoutID)
                
                switch payload.action {
                case .startWorkout:
                    guard let uuid = workoutUUID else { return }
                    let newWorkout = Workout(id: uuid, title: payload.workoutTitle ?? "Watch Workout", date: Date(), exercises: [])
                    newWorkout.icon = "applewatch"
                    bgContext.insert(newWorkout)

                    if let exercisesDTO = payload.exercises {
                        for dto in exercisesDTO {
                            let exercise = Exercise(from: dto)
                            bgContext.insert(exercise)
                            for set in exercise.setsList { bgContext.insert(set) }
                            for sub in exercise.subExercises { bgContext.insert(sub) }
                            exercise.workout = newWorkout
                            newWorkout.exercises.append(exercise)
                        }
                    }
                    try? bgContext.save()
                    
                    self.liveActivityManager.startWorkoutActivity(title: newWorkout.title)
                    self.appState.returnToActiveWorkoutId = newWorkout.persistentModelID
                    
                case .addExercise:
                    guard let uuid = workoutUUID, let exName = payload.exerciseName else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first {
                        let newEx = Exercise(name: exName, muscleGroup: "Mixed", type: .strength, sets: 0, reps: 0, weight: 0)
                        bgContext.insert(newEx)
                        newEx.workout = workout
                        workout.exercises.append(newEx)
                        try? bgContext.save()
                    }
                    
                case .logSet:
                    guard let uuid = workoutUUID, let exName = payload.exerciseName, let setIndex = payload.setIndex else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first,
                       let exercise = workout.exercises.first(where: { $0.name == exName }),
                       let setToUpdate = exercise.setsList.first(where: { $0.index == setIndex }) {
                        
                        // ✅ ИСПРАВЛЕНИЕ: Обновляем существующий сет, а не создаем новый
                        setToUpdate.weight = payload.weight
                        setToUpdate.reps = payload.reps
                        setToUpdate.isCompleted = payload.isCompleted ?? true
                        try? bgContext.save()
                    }
                    
                case .updateEffort:
                    guard let uuid = workoutUUID, let exName = payload.exerciseName, let effort = payload.effort else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first,
                       let exercise = workout.exercises.first(where: { $0.name == exName }) {
                        exercise.effort = effort
                        exercise.isCompleted = true // ✅ ИСПРАВЛЕНИЕ: Завершаем упражнение
                        try? bgContext.save()
                    }
                    
                case .finishWorkout:
                    guard let uuid = workoutUUID else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first {
                        await self.processCompletedWorkout(workout)
                        self.appState.returnToActiveWorkoutId = nil
                    }
                    
                case .saveToHistory:
                    guard let uuid = workoutUUID else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first {
                        if let dDuration = payload.durationSeconds { workout.durationSeconds = dDuration }
                        
                        if let exercisesDTO = payload.exercises {
                            for old in workout.exercises { bgContext.delete(old) }
                            workout.exercises.removeAll()
                            for dto in exercisesDTO {
                                let ex = Exercise(from: dto)
                                bgContext.insert(ex)
                                ex.workout = workout
                                workout.exercises.append(ex)
                            }
                        }
                        try? bgContext.save()
                        await self.processCompletedWorkout(workout)
                        self.appState.returnToActiveWorkoutId = nil
                    }

                case .discardWorkout:
                    guard let uuid = workoutUUID else { return }
                    let desc = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == uuid })
                    if let workout = try? bgContext.fetch(desc).first {
                        await self.deleteWorkout(workout)
                    }
                    
                case .requestActiveState, .syncFullState, .updateHeartRate: // 👈 ДОБАВЛЕНО .updateHeartRate
                                    break
                                }
            }
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
            return try await workoutStore.fetchLatestWorkout()
        } catch {
            appState.showError(title: "Error", message: "Failed to fetch latest workout")
            return nil
        }
    }
    
    // MARK: - Workout Management
    func createWorkout(title: String, presetID: PersistentIdentifier?, isAIGenerated: Bool) async -> PersistentIdentifier? {
        do {
            try? await HealthKitManager.shared.requestAuthorization()
            let id = try await workoutStore.createWorkout(title: title, fromPresetID: presetID, isAIGenerated: isAIGenerated)
            return id
        } catch {
            appState.showError(title: String(localized: "Error"), message: error.localizedDescription)
            return nil
        }
    }
        
    func startGeneratedWorkout(_ generated: GeneratedWorkoutDTO) async {
        do {
            try? await HealthKitManager.shared.requestAuthorization()
            _ = try await workoutStore.createWorkoutFromAI(generated: generated)
            liveActivityManager.startWorkoutActivity(title: generated.title)
        } catch {
            appState.showError(
                title: String(localized: "Save Failed"),
                message: String(localized: "Failed to save generated workout: \(error.localizedDescription)")
            )
        }
    }
    
    func hasActiveWorkout() async -> Bool {
        do {
            let activeIDs = try await workoutStore.findActiveWorkoutsAndCleanup()
            return !activeIDs.isEmpty
        } catch {
            print("Error checking for active workouts: \(error)")
            return false
        }
    }
    
    // MARK: - Entity Manipulation
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

    func updateWorkoutChatHistory(workout: Workout, history: [AIChatMessage]) async {
        do {
            try await workoutStore.updateWorkoutChatHistory(workoutID: workout.persistentModelID, history: history)
        } catch {
            appState.showError(title: "Error", message: "Could not update AI chat history: \(error.localizedDescription)")
        }
    }

    func processCompletedWorkout(_ workout: Workout) async {
            do {
                try await workoutStore.processCompletedWorkout(workoutID: workout.persistentModelID)
                liveActivityManager.stopAllActivities()
                
                let wTitle = workout.title
                let wStart = workout.date
                let wEnd = workout.endTime ?? Date()
                let wDuration = workout.durationSeconds > 0 ? workout.durationSeconds : Int(wEnd.timeIntervalSince(wStart))
                
                // ✅ Считаем калории
                let userWeight = UserDefaults.standard.double(forKey: Constants.UserDefaultsKeys.userBodyWeight.rawValue)
                let burnedCalories = CalorieCalculator.calculate(for: workout, userWeight: userWeight)
                
                Task.detached {
                    do {
                        try await HealthKitManager.shared.requestAuthorization()
                        try await HealthKitManager.shared.saveWorkout(
                            title: wTitle,
                            startDate: wStart,
                            endDate: wEnd,
                            durationSeconds: wDuration,
                            calories: burnedCalories // <--- Передаем готовые калории
                        )
                    } catch {
                        print("⚠️ Failed to sync workout to HealthKit: \(error)")
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
        do {
            try await workoutStore.deleteWorkout(workoutID: workout.persistentModelID)
            stopLiveActivity()
        } catch {
            appState.showError(title: "Delete Failed", message: "Could not delete workout: \(error.localizedDescription)")
        }
    }

    func deleteWorkout(byID id: PersistentIdentifier) async {
        do {
            try await workoutStore.deleteWorkout(workoutID: id)
            stopLiveActivity()
        } catch {
            appState.showError(title: "Delete Failed", message: "Could not delete workout: \(error.localizedDescription)")
        }
    }

    func cleanupAndFindActiveWorkouts() async {
        do {
            let activeIDs = try await workoutStore.findActiveWorkoutsAndCleanup()
            if activeIDs.isEmpty { stopLiveActivity() }
        } catch {
            print("Cleanup failed: \(error.localizedDescription)")
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
            print("Failed to generate default presets: \(error.localizedDescription)")
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
            try await workoutStore.applySmartAction(proposal: proposal, inWorkoutID: workout.persistentModelID)
            await updateWidgetData()
        } catch {
            appState.showError(title: "Database Error", message: "Failed to apply AI changes.")
        }
    }
}
