// ============================================================
// FILE: WorkoutTracker/Views/Workout/WorkoutDetailViewModel.swift
// ============================================================

internal import SwiftUI
import SwiftData
import Observation
import ActivityKit

@Observable
@MainActor
final class WorkoutDetailViewModel {
    var aiCoach: InWorkoutAICoachViewModel
    var workoutAnalytics = WorkoutAnalyticsDataDTO()
    var activeDestination: DetailDestination? = nil
    var snackbarMessage: LocalizedStringKey?
    var shareItems: [Any] = []
    
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
        set { if !newValue && activeDestination == .emptyWorkoutAlert { activeDestination = nil } }
    }
    
    private let workoutService: WorkoutService
    private let analyticsService: AnalyticsService
    private let exerciseCatalogService: ExerciseCatalogService
    
    @ObservationIgnored private var snackbarCommitAction: (() -> Void)?
    @ObservationIgnored private var snackbarUndoAction: (() -> Void)?
    @ObservationIgnored private var snackbarTask: Task<Void, Never>?

    init(workoutService: WorkoutService, analyticsService: AnalyticsService, exerciseCatalogService: ExerciseCatalogService) {
        self.workoutService = workoutService
        self.analyticsService = analyticsService
        self.exerciseCatalogService = exerciseCatalogService
        
        self.aiCoach = InWorkoutAICoachViewModel(
            workoutService: workoutService,
            aiLogicService: workoutService.aiLogicService,
            analyticsService: analyticsService,
            exerciseCatalogService: exerciseCatalogService
        )
    }
    
    func updateWorkoutAnalytics(for workout: Workout) {
        let workoutID = workout.persistentModelID
        Task {
            if let analytics = try? await analyticsService.fetchWorkoutAnalytics(workoutID: workoutID) {
                await MainActor.run { self.workoutAnalytics = analytics }
            }
        }
    }
    
    func handlePRSet(level: PRLevel, exerciseName: String, workout: Workout, weightUnit: String) {
        self.activeDestination = .prCelebration(level)
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if case .prCelebration = self.activeDestination { self.activeDestination = nil }
        }
        Task { await self.aiCoach.triggerProactiveFeedback(for: nil, isLastSet: false, isPR: true, prLevel: level.title, in: exerciseName, currentWorkout: workout, weightUnit: weightUnit) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func handleSetCompleted(set: WorkoutSet, isLast: Bool, exerciseName: String, workout: Workout, catalog: [String: [String]], weightUnit: String) {
        Task { await self.aiCoach.triggerProactiveFeedback(for: set, isLastSet: isLast, isPR: false, prLevel: nil, in: exerciseName, currentWorkout: workout, weightUnit: weightUnit) }
    }

    func handleExerciseFinished(exerciseId: UUID, workout: Workout, modelContainer: ModelContainer, tutorialManager: TutorialManager, dashboardViewModel: DashboardViewModel, catalog: [String: [String]], weightUnit: String, onExpandNext: @escaping (UUID) -> Void) {
        guard let exercise = workout.exercises.first(where: { $0.id == exerciseId }) else { return }
        let exerciseIndex = workout.exercises.firstIndex(of: exercise) ?? 0

        if exercise.isSuperset {
            finishSuperset(exercise, workout: workout, dashboardViewModel: dashboardViewModel, weightUnit: weightUnit)
        } else {
            finishExercise(exercise, workout: workout, tutorialManager: tutorialManager, dashboardViewModel: dashboardViewModel, weightUnit: weightUnit)
        }

        if let nextIndex = workout.exercises.indices.first(where: { $0 > exerciseIndex && !workout.exercises[$0].isCompleted }) {
            onExpandNext(workout.exercises[nextIndex].id)
        }
    }
    
    func addExercise(_ newExercise: Exercise, workout: Workout, scrollToExerciseId: @escaping (UUID) -> Void) {
        withAnimation { workout.exercises.insert(newExercise, at: 0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { scrollToExerciseId(newExercise.id) }
    }

    func performSwap(old: Exercise, new: Exercise, workout: Workout) {
        guard let index = workout.exercises.firstIndex(where: { $0.id == old.id }) else { return }
        withAnimation {
            workout.exercises.insert(new, at: index)
            Task { await workoutService.removeExercise(old, from: workout) }
        }
        updateWorkoutAnalytics(for: workout)
    }
    func deleteEmptyWorkout(workout: Workout, timerManager: RestTimerManager, dismiss: DismissAction) {
        Task { await workoutService.deleteWorkout(workout) }
        timerManager.stopRestTimer()
        dismiss()
    }
    
    func undoAction() {
        snackbarTask?.cancel()
        withAnimation { snackbarUndoAction?(); snackbarMessage = nil }
        resetSnackbar()
    }

    func commitSnackbar() {
        guard snackbarMessage != nil else { return }
        snackbarCommitAction?()
        withAnimation { snackbarMessage = nil }
        resetSnackbar()
    }

    private func resetSnackbar() {
        snackbarTask?.cancel()
        snackbarCommitAction = nil
        snackbarUndoAction = nil
        snackbarTask = nil
    }

    func generateAndShare(workout: Workout) {
        let renderer = ImageRenderer(content: WorkoutShareCard(workout: workout))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            self.shareItems = [uiImage]
            self.activeDestination = .shareSheet
        }
    }
    
    func finishWorkout(workout: Workout, progressManager: ProgressManager, onRefreshGlobalCaches: @escaping () -> Void, updateAchievementsCount: @escaping (Int) -> Int, onSuccessUI: @escaping () -> Void) {
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
        
        withAnimation {
            workout.endTime = Date()
            onSuccessUI()
            snackbarMessage = "Workout finished"
        }
        
        snackbarCommitAction = { [weak self] in
            self?.executeFinishWorkoutBackend(workout: workout, progressManager: progressManager, onRefreshGlobalCaches: onRefreshGlobalCaches, updateAchievementsCount: updateAchievementsCount)
        }
        snackbarUndoAction = { workout.endTime = nil }
        
        snackbarTask = Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if !Task.isCancelled { self.commitSnackbar() }
        }
    }
    
    private func executeFinishWorkoutBackend(workout: Workout, progressManager: ProgressManager, onRefreshGlobalCaches: @escaping () -> Void, updateAchievementsCount: @escaping (Int) -> Int) {
        progressManager.addXP(for: workout)
        NotificationCenter.default.post(name: .workoutCompletedEvent, object: workout.persistentModelID, userInfo: ["modelContainer": analyticsService.modelContainer])
        
        let workoutID = workout.persistentModelID
        Task {
            if let result = try? await analyticsService.finishWorkoutAndCalculateAchievements(workoutID: workoutID) {
                await MainActor.run {
                    onRefreshGlobalCaches()
                    _ = updateAchievementsCount(result.totalCount)
                    if let firstUnlock = result.newUnlocks.first {
                        self.activeDestination = .achievementPopup(firstUnlock)
                    }
                }
            }
        }
    }
    
    private func finishExercise(_ exercise: Exercise, workout: Workout, tutorialManager: TutorialManager, dashboardViewModel: DashboardViewModel, weightUnit: String) {
        guard !exercise.isCompleted && workout.isActive else { return }
        
        let uncompletedSets = exercise.setsList.filter { !$0.isCompleted }
        Task { for s in uncompletedSets { await workoutService.deleteSet(s, from: exercise) } }
        
        exercise.isCompleted = true
        if tutorialManager.currentStep == .finishExercise { tutorialManager.setStep(.explainEffort) }
        
        if let prLevel = calculatePRLevel(for: exercise, prCache: dashboardViewModel.personalRecordsCache) {
            handlePRSet(level: prLevel, exerciseName: exercise.name, workout: workout, weightUnit: weightUnit)
        }
    }
    
    private func finishSuperset(_ superset: Exercise, workout: Workout, dashboardViewModel: DashboardViewModel, weightUnit: String) {
        guard !superset.isCompleted && workout.isActive else { return }
        
        for sub in superset.subExercises {
            let uncompleted = sub.setsList.filter { !$0.isCompleted }
            Task { for s in uncompleted { await workoutService.deleteSet(s, from: sub) } }
            sub.isCompleted = true
        }
        
        superset.isCompleted = true
        superset.updateAggregates()
        
        var highestPR: PRLevel? = nil
        for sub in superset.subExercises {
            if let pr = calculatePRLevel(for: sub, prCache: dashboardViewModel.personalRecordsCache) {
                if highestPR == nil || pr.rank > highestPR!.rank { highestPR = pr }
            }
        }
        
        if let pr = highestPR {
            handlePRSet(level: pr, exerciseName: superset.name, workout: workout, weightUnit: weightUnit)
        }
    }
    
    private func calculatePRLevel(for exercise: Exercise, prCache: [String: Double]) -> PRLevel? {
        guard exercise.type == .strength else { return nil }
        let maxWeight = exercise.setsList.filter { $0.isCompleted }.compactMap { $0.weight }.max() ?? 0.0
        let oldRecord = prCache[exercise.name] ?? 0.0
        
        if maxWeight > oldRecord && oldRecord > 0 {
            let increase = (maxWeight - oldRecord) / oldRecord
            if increase >= 0.20 { return .diamond }
            if increase >= 0.10 { return .gold }
            if increase >= 0.05 { return .silver }
            return .bronze
        }
        return nil
    }
}
