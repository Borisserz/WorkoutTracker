//
//  WorkoutDetailViewModel.swift
//  WorkoutTracker
//
internal import SwiftUI
import SwiftData
import ActivityKit
import Combine
internal import UniformTypeIdentifiers

@MainActor
final class WorkoutDetailViewModel: ObservableObject {
    
    // MARK: - Nested ViewModels
    @Published var aiCoach = InWorkoutAICoachViewModel()
    
    // MARK: - Published State (UI & Modals)
    @Published var showShareSheet = false
    @Published var showEmptyWorkoutAlert = false
    @Published var showPRCelebration = false
    @Published var prLevel: PRLevel = .bronze
    @Published var newlyUnlockedAchievement: Achievement?
    @Published var snackbarMessage: LocalizedStringKey?
    @Published var shareItems: [UIImage] = []
    
    // Состояния шторок (Sheets)
    @Published var showExerciseSelection = false
    @Published var showSupersetBuilder = false
    @Published var showSwapSheet = false
    @Published var exerciseToSwap: Exercise?
    @Published var supersetToEdit: Exercise?
    
    // MARK: - Internal State
    private var snackbarCommitAction: (() -> Void)?
    private var snackbarUndoAction: (() -> Void)?
    private var snackbarTask: Task<Void, Never>?
    
    // MARK: - Handlers (PR & Sets)
    
    func handlePRSet(level: PRLevel, exerciseName: String, workout: Workout, catalog: [String: [String]], weightUnit: String) {
        self.prLevel = level
        self.showPRCelebration = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            self.showPRCelebration = false
        }
        self.aiCoach.triggerProactiveFeedback(
            for: nil, isLastSet: false, isPR: true, prLevel: level.title, in: exerciseName,
            currentWorkout: workout, catalog: catalog, weightUnit: weightUnit
        )
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func handleSetCompleted(set: WorkoutSet, isLast: Bool, exerciseName: String, workout: Workout, catalog: [String: [String]], weightUnit: String) {
        self.aiCoach.triggerProactiveFeedback(
            for: set, isLastSet: isLast, isPR: false, prLevel: nil, in: exerciseName,
            currentWorkout: workout, catalog: catalog, weightUnit: weightUnit
        )
    }

    func handleExerciseFinished(
        exerciseId: UUID,
        workout: Workout,
        modelContainer: ModelContainer,
        tutorialManager: TutorialManager,
        prCache: [String: Double],
        catalog: [String: [String]],
        weightUnit: String,
        onExpandNext: @escaping (UUID) -> Void
    ) {
        guard let exercise = workout.exercises.first(where: { $0.id == exerciseId }) else { return }
        let exerciseIndex = workout.exercises.firstIndex(of: exercise) ?? 0

        let onPRSet: (PRLevel) -> Void = { [weak self] level in
            self?.handlePRSet(level: level, exerciseName: exercise.name, workout: workout, catalog: catalog, weightUnit: weightUnit)
        }
        
        let onShowEffort: () -> Void = { } // Оставлено пустым для совместимости с будущим попапом RPE

        if exercise.isSuperset {
            finishSuperset(exercise, workout: workout, modelContainer: modelContainer, prCache: prCache, onPRSet: onPRSet, onShowEffort: onShowEffort)
        } else {
            finishExercise(exercise, workout: workout, modelContainer: modelContainer, tutorialManager: tutorialManager, prCache: prCache, onPRSet: onPRSet, onShowEffort: onShowEffort)
        }

        if let nextIndex = workout.exercises.indices.first(where: { $0 > exerciseIndex && !workout.exercises[$0].isCompleted }) {
            let nextExercise = workout.exercises[nextIndex]
            onExpandNext(nextExercise.id)
        }
    }
    
    // MARK: - Actions
    
    func addExercise(_ newExercise: Exercise, workout: Workout, scrollToExerciseId: @escaping (UUID) -> Void) {
        withAnimation { workout.exercises.insert(newExercise, at: 0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { scrollToExerciseId(newExercise.id) }
    }

    func performSwap(old: Exercise, new: Exercise, workout: Workout, globalViewModel: WorkoutViewModel) {
        guard let index = workout.exercises.firstIndex(where: { $0.id == old.id }) else { return }
        withAnimation {
            workout.exercises.insert(new, at: index)
            globalViewModel.removeExercise(old, from: workout)
        }
        globalViewModel.updateWorkoutAnalytics(for: workout)
    }

    func deleteEmptyWorkout(workout: Workout, globalViewModel: WorkoutViewModel, timerManager: RestTimerManager, dismiss: DismissAction) {
        globalViewModel.deleteWorkout(workout)
        timerManager.stopRestTimer()
        dismiss()
    }
    
    // MARK: - Snackbar & Undo Logic
    
    func executeWithUndo(message: LocalizedStringKey, optimisticUpdate: @escaping () -> Void, commit: @escaping () -> Void, undo: @escaping () -> Void) {
        commitSnackbar()
        withAnimation {
            optimisticUpdate()
            snackbarMessage = message
        }
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
        withAnimation {
            snackbarUndoAction?()
            snackbarMessage = nil
        }
        snackbarCommitAction = nil
        snackbarUndoAction = nil
    }
    
    // MARK: - Share Logic
    
    func generateAndShare(workout: Workout) {
        let renderer = ImageRenderer(content: WorkoutShareCard(workout: workout))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            self.shareItems = [uiImage]
            self.showShareSheet = true
        }
    }
    
    // MARK: - Workout Lifecycle
    
    func finishWorkout(
        workout: Workout,
        modelContainer: ModelContainer,
        progressManager: ProgressManager,
        onRefreshGlobalCaches: @escaping () -> Void,
        updateAchievementsCount: @escaping (Int) -> Int,
        onSuccessUI: @escaping () -> Void
    ) {
        var hasAnyCompletedSet = false
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            if targets.contains(where: { $0.setsList.contains(where: { $0.isCompleted }) }) {
                hasAnyCompletedSet = true
                break
            }
        }
        
        guard hasAnyCompletedSet else {
            showEmptyWorkoutAlert = true
            return
        }
        
        let commitAction: () -> Void = { [weak self] in
            self?.executeFinishWorkoutBackend(
                workout: workout,
                modelContainer: modelContainer,
                progressManager: progressManager,
                onRefreshGlobalCaches: onRefreshGlobalCaches,
                updateAchievementsCount: updateAchievementsCount
            )
        }
        
        executeWithUndo(
            message: "Workout finished",
            optimisticUpdate: {
                workout.endTime = Date()
                onSuccessUI()
            },
            commit: commitAction,
            undo: {
                workout.endTime = nil
            }
        )
    }
    
    private func executeFinishWorkoutBackend(
        workout: Workout,
        modelContainer: ModelContainer,
        progressManager: ProgressManager,
        onRefreshGlobalCaches: @escaping () -> Void,
        updateAchievementsCount: @escaping (Int) -> Int
    ) {
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
                        self.newlyUnlockedAchievement = firstUnlock
                    } else if result.totalCount > oldCount {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            }
        }
    }
    
    // MARK: - Exercise & Superset Completion Logic
    
    func finishExercise(
        _ exercise: Exercise,
        workout: Workout,
        modelContainer: ModelContainer,
        tutorialManager: TutorialManager,
        prCache: [String: Double],
        onPRSet: @escaping (PRLevel) -> Void,
        onShowEffort: @escaping () -> Void
    ) {
        guard !exercise.isCompleted && workout.isActive else { return }
        
        let uncompletedSets = exercise.setsList.filter { !$0.isCompleted }
        let exerciseID = exercise.persistentModelID
        let setIDs = uncompletedSets.map { $0.persistentModelID }
        
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            for setID in setIDs {
                try? await repository.deleteSet(setID: setID, fromExerciseID: exerciseID)
            }
        }
        
        exercise.isCompleted = true
        
        if tutorialManager.currentStep == .finishExercise {
            tutorialManager.setStep(.explainEffort)
        }
        
        if let prLevel = calculatePRLevel(for: exercise, prCache: prCache) {
            onPRSet(prLevel)
        } else {
            onShowEffort()
        }
    }
    
    func finishSuperset(
        _ superset: Exercise,
        workout: Workout,
        modelContainer: ModelContainer,
        prCache: [String: Double],
        onPRSet: @escaping (PRLevel) -> Void,
        onShowEffort: @escaping () -> Void
    ) {
        guard !superset.isCompleted && workout.isActive else { return }
        
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            for sub in superset.subExercises {
                let subID = sub.persistentModelID
                let uncompletedSetIDs = sub.setsList.filter { !$0.isCompleted }.map { $0.persistentModelID }
                for setID in uncompletedSetIDs {
                    try? await repository.deleteSet(setID: setID, fromExerciseID: subID)
                }
            }
        }
        
        for sub in superset.subExercises {
            sub.isCompleted = true
        }
        superset.isCompleted = true
        superset.updateAggregates()
        
        var highestPR: PRLevel? = nil
        for subExercise in superset.subExercises {
            if let pr = calculatePRLevel(for: subExercise, prCache: prCache) {
                if highestPR == nil || pr.rank > highestPR!.rank {
                    highestPR = pr
                }
            }
        }
        
        if let pr = highestPR {
            onPRSet(pr)
        } else {
            onShowEffort()
        }
    }
    
    private func calculatePRLevel(for exercise: Exercise, prCache: [String: Double]) -> PRLevel? {
        guard exercise.type == .strength else { return nil }
        
        let maxWeightInWorkout = exercise.setsList
            .filter { $0.isCompleted }
            .compactMap { $0.weight }
            .max() ?? 0.0
        
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
