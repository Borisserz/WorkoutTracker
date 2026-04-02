internal import SwiftUI
import SwiftData
import ActivityKit
import Combine
internal import UniformTypeIdentifiers
import Observation

// MARK: - Analytics DTO
struct WorkoutAnalyticsData: Sendable {
    var intensity: [String: Int] = [:]
    var volume: Double = 0.0
    var chartExercises: [ExerciseChartDTO] = []
}

// MARK: - State-Driven Router Enum
enum DetailDestination: Identifiable, Equatable {
    case shareSheet
    case emptyWorkoutAlert
    case prCelebration(PRLevel)
    case achievementPopup(Achievement)
    case exerciseSelection
    case supersetBuilder(Exercise?)
    case swapExercise(Exercise)
    
    var id: String {
        switch self {
        case .shareSheet: return "share"
        case .emptyWorkoutAlert: return "emptyAlert"
        case .prCelebration: return "pr"
        case .achievementPopup(let a): return "ach_\(a.id)"
        case .exerciseSelection: return "exSel"
        case .supersetBuilder(let ex): return "super_\(ex?.id.uuidString ?? "new")"
        case .swapExercise(let ex): return "swap_\(ex.id.uuidString)"
        }
    }
    
    static func == (lhs: DetailDestination, rhs: DetailDestination) -> Bool {
        return lhs.id == rhs.id
    }
    
    var isSheet: Bool {
        switch self {
        case .shareSheet, .exerciseSelection, .supersetBuilder, .swapExercise: return true
        default: return false
        }
    }
    
    var isFullScreen: Bool {
        switch self {
        case .prCelebration, .achievementPopup: return true
        default: return false
        }
    }
}

// MARK: - ViewModel
@Observable
@MainActor
final class WorkoutDetailViewModel {
    var aiCoach = InWorkoutAICoachViewModel()
    var workoutAnalytics = WorkoutAnalyticsData()
    
    // ЕДИНАЯ ТОЧКА ИСТИНЫ для всех модальных окон
    var activeDestination: DetailDestination? = nil
    
    var snackbarMessage: LocalizedStringKey?
    var shareItems: [Any] = []
    
    // BACKWARD COMPATIBILITY
    var showExerciseSelection: Bool {
        get { activeDestination == .exerciseSelection }
        set { activeDestination = newValue ? .exerciseSelection : nil }
    }
    var showSupersetBuilder: Bool {
        get { if case .supersetBuilder = activeDestination { return true } else { return false } }
        set { activeDestination = newValue ? .supersetBuilder(nil) : nil }
    }
    var showSwapSheet: Bool {
        get { if case .swapExercise = activeDestination { return true } else { return false } }
        set { if !newValue { activeDestination = nil } }
    }
    var exerciseToSwap: Exercise? {
        get { if case .swapExercise(let ex) = activeDestination { return ex } else { return nil } }
        set { activeDestination = newValue != nil ? .swapExercise(newValue!) : nil }
    }
    var supersetToEdit: Exercise? {
        get { if case .supersetBuilder(let ex) = activeDestination { return ex } else { return nil } }
        set { activeDestination = newValue != nil ? .supersetBuilder(newValue) : nil }
    }
    var activeSheet: DetailDestination? {
        get { activeDestination?.isSheet == true ? activeDestination : nil }
        set { if newValue == nil { activeDestination = nil } else { activeDestination = newValue } }
    }
    var activeFullScreen: DetailDestination? {
        get { activeDestination?.isFullScreen == true ? activeDestination : nil }
        set { if newValue == nil { activeDestination = nil } else { activeDestination = newValue } }
    }
    var isShowingEmptyAlert: Bool {
        get { activeDestination == .emptyWorkoutAlert }
        set { if !newValue { activeDestination = nil } }
    }
    
    @ObservationIgnored private var snackbarCommitAction: (() -> Void)?
    @ObservationIgnored private var snackbarUndoAction: (() -> Void)?
    @ObservationIgnored private var snackbarTask: Task<Void, Never>?
    
    func updateWorkoutAnalytics(for workout: Workout, modelContainer: ModelContainer) {
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            if let analytics = try? await repository.fetchWorkoutAnalytics(workoutID: workoutID) {
                await MainActor.run { self.workoutAnalytics = analytics }
            }
        }
    }
    
    func handlePRSet(level: PRLevel, exerciseName: String, workout: Workout, catalog: [String: [String]], weightUnit: String) {
        self.activeDestination = .prCelebration(level)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if case .prCelebration = self.activeDestination { self.activeDestination = nil }
        }
        self.aiCoach.triggerProactiveFeedback(for: nil, isLastSet: false, isPR: true, prLevel: level.title, in: exerciseName, currentWorkout: workout, catalog: catalog, weightUnit: weightUnit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func handleSetCompleted(set: WorkoutSet, isLast: Bool, exerciseName: String, workout: Workout, catalog: [String: [String]], weightUnit: String) {
        self.aiCoach.triggerProactiveFeedback(for: set, isLastSet: isLast, isPR: false, prLevel: nil, in: exerciseName, currentWorkout: workout, catalog: catalog, weightUnit: weightUnit)
    }

    func handleExerciseFinished(exerciseId: UUID, workout: Workout, modelContainer: ModelContainer, tutorialManager: TutorialManager, dashboardViewModel: DashboardViewModel, catalog: [String: [String]], weightUnit: String, onExpandNext: @escaping (UUID) -> Void) {
        guard let exercise = workout.exercises.first(where: { $0.id == exerciseId }) else { return }
        let exerciseIndex = workout.exercises.firstIndex(of: exercise) ?? 0

        let onPRSet: (PRLevel) -> Void = { [weak self] level in
            self?.handlePRSet(level: level, exerciseName: exercise.name, workout: workout, catalog: catalog, weightUnit: weightUnit)
        }
        let onShowEffort: () -> Void = { }

        if exercise.isSuperset {
            finishSuperset(exercise, workout: workout, modelContainer: modelContainer, dashboardViewModel: dashboardViewModel, onPRSet: onPRSet, onShowEffort: onShowEffort)
        } else {
            finishExercise(exercise, workout: workout, modelContainer: modelContainer, tutorialManager: tutorialManager, dashboardViewModel: dashboardViewModel, onPRSet: onPRSet, onShowEffort: onShowEffort)
        }

        if let nextIndex = workout.exercises.indices.first(where: { $0 > exerciseIndex && !workout.exercises[$0].isCompleted }) {
            let nextExercise = workout.exercises[nextIndex]
            onExpandNext(nextExercise.id)
        }
    }
    
    func addExercise(_ newExercise: Exercise, workout: Workout, scrollToExerciseId: @escaping (UUID) -> Void) {
        withAnimation { workout.exercises.insert(newExercise, at: 0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { scrollToExerciseId(newExercise.id) }
    }

    func performSwap(old: Exercise, new: Exercise, workout: Workout, globalViewModel: WorkoutViewModel, modelContainer: ModelContainer) {
        guard let index = workout.exercises.firstIndex(where: { $0.id == old.id }) else { return }
        withAnimation {
            workout.exercises.insert(new, at: index)
            globalViewModel.removeExercise(old, from: workout)
        }
        updateWorkoutAnalytics(for: workout, modelContainer: modelContainer)
    }

    func deleteEmptyWorkout(workout: Workout, globalViewModel: WorkoutViewModel, timerManager: RestTimerManager, dismiss: DismissAction) {
        globalViewModel.deleteWorkout(workout)
        timerManager.stopRestTimer()
        dismiss()
    }
    
    func executeWithUndo(message: LocalizedStringKey, optimisticUpdate: @escaping () -> Void, commit: @escaping () -> Void, undo: @escaping () -> Void) {
        commitSnackbar()
        withAnimation { optimisticUpdate(); snackbarMessage = message }
        snackbarCommitAction = commit
        snackbarUndoAction = undo
        snackbarTask?.cancel()
        snackbarTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if !Task.isCancelled { self.commitSnackbar() }
        }
    }
    
    func commitSnackbar() {
        guard snackbarMessage != nil else { return }
        snackbarCommitAction?()
        withAnimation { snackbarMessage = nil }
        snackbarCommitAction = nil
        snackbarUndoAction = nil
        snackbarTask?.cancel()
        snackbarTask = nil
    }
    
    func undoAction() {
        snackbarTask?.cancel()
        snackbarTask = nil
        withAnimation { snackbarUndoAction?(); snackbarMessage = nil }
        snackbarCommitAction = nil
        snackbarUndoAction = nil
    }
    
    func generateAndShare(workout: Workout) {
        let renderer = ImageRenderer(content: WorkoutShareCard(workout: workout))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            self.shareItems = [uiImage]
            self.activeDestination = .shareSheet
        }
    }
    
    func finishWorkout(workout: Workout, modelContainer: ModelContainer, progressManager: ProgressManager, onRefreshGlobalCaches: @escaping () -> Void, updateAchievementsCount: @escaping (Int) -> Int, onSuccessUI: @escaping () -> Void) {
        var hasAnyCompletedSet = false
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            if targets.contains(where: { $0.setsList.contains(where: { $0.isCompleted }) }) {
                hasAnyCompletedSet = true; break
            }
        }
        guard hasAnyCompletedSet else {
            self.activeDestination = .emptyWorkoutAlert
            return
        }
        
        let commitAction: () -> Void = { [weak self] in
            self?.executeFinishWorkoutBackend(workout: workout, modelContainer: modelContainer, progressManager: progressManager, onRefreshGlobalCaches: onRefreshGlobalCaches, updateAchievementsCount: updateAchievementsCount)
        }
        executeWithUndo(message: "Workout finished", optimisticUpdate: { workout.endTime = Date(); onSuccessUI() }, commit: commitAction, undo: { workout.endTime = nil })
    }
    
    private func executeFinishWorkoutBackend(workout: Workout, modelContainer: ModelContainer, progressManager: ProgressManager, onRefreshGlobalCaches: @escaping () -> Void, updateAchievementsCount: @escaping (Int) -> Int) {
        progressManager.addXP(for: workout)
        NotificationManager.shared.scheduleNotifications(after: workout)
        
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                let finalState = WorkoutActivityAttributes.ContentState(startTime: Date())
                await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(5)))
            }
        }
        
        let workoutID = workout.persistentModelID
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            if let result = try? await repository.finishWorkoutAndCalculateAchievements(workoutID: workoutID) {
                await MainActor.run {
                    onRefreshGlobalCaches()
                    let oldCount = updateAchievementsCount(result.totalCount)
                    if let firstUnlock = result.newUnlocks.first {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        self.activeDestination = .achievementPopup(firstUnlock)
                    } else if result.totalCount > oldCount {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            }
        }
    }
    
    func finishExercise(_ exercise: Exercise, workout: Workout, modelContainer: ModelContainer, tutorialManager: TutorialManager, dashboardViewModel: DashboardViewModel, onPRSet: @escaping (PRLevel) -> Void, onShowEffort: @escaping () -> Void) {
        guard !exercise.isCompleted && workout.isActive else { return }
        let uncompletedSets = exercise.setsList.filter { !$0.isCompleted }
        let exerciseID = exercise.persistentModelID
        let setIDs = uncompletedSets.map { $0.persistentModelID }
        
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            for setID in setIDs { try? await repository.deleteSet(setID: setID, fromExerciseID: exerciseID) }
        }
        
        exercise.isCompleted = true
        if tutorialManager.currentStep == .finishExercise { tutorialManager.setStep(.explainEffort) }
        
        if let prLevel = calculatePRLevel(for: exercise, prCache: dashboardViewModel.personalRecordsCache) {
            onPRSet(prLevel)
        } else { onShowEffort() }
    }
    
    func finishSuperset(_ superset: Exercise, workout: Workout, modelContainer: ModelContainer, dashboardViewModel: DashboardViewModel, onPRSet: @escaping (PRLevel) -> Void, onShowEffort: @escaping () -> Void) {
        guard !superset.isCompleted && workout.isActive else { return }
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            for sub in superset.subExercises {
                let subID = sub.persistentModelID
                let uncompletedSetIDs = sub.setsList.filter { !$0.isCompleted }.map { $0.persistentModelID }
                for setID in uncompletedSetIDs { try? await repository.deleteSet(setID: setID, fromExerciseID: subID) }
            }
        }
        for sub in superset.subExercises { sub.isCompleted = true }
        superset.isCompleted = true
        superset.updateAggregates()
        
        var highestPR: PRLevel? = nil
        for subExercise in superset.subExercises {
            if let pr = calculatePRLevel(for: subExercise, prCache: dashboardViewModel.personalRecordsCache) {
                if highestPR == nil || pr.rank > highestPR!.rank { highestPR = pr }
            }
        }
        if let pr = highestPR { onPRSet(pr) } else { onShowEffort() }
    }
    
    private func calculatePRLevel(for exercise: Exercise, prCache: [String: Double]) -> PRLevel? {
        guard exercise.type == .strength else { return nil }
        let maxWeightInWorkout = exercise.setsList.filter { $0.isCompleted }.compactMap { $0.weight }.max() ?? 0.0
        let oldRecord = prCache[exercise.name] ?? 0.0
        
        if maxWeightInWorkout > oldRecord && oldRecord > 0 {
            let increasePercent = (maxWeightInWorkout - oldRecord) / oldRecord
            if increasePercent >= 0.20 { return .diamond }
            if increasePercent >= 0.10 { return .gold }
            if increasePercent >= 0.05 { return .silver }
            return .bronze
        }
        return nil
    }
}
