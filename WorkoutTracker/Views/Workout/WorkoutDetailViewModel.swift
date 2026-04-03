// ============================================================
// FILE: WorkoutTracker/Views/Workout/WorkoutDetailViewModel.swift
// ============================================================

internal import SwiftUI
import SwiftData
import Observation

/// События, которые ViewModel отправляет во View для управления навигацией и алертами
enum WorkoutDetailEvent: Equatable {
    case showPR(PRLevel)
    case showShareSheet(UIImage)
    case showEmptyAlert
    case showAchievement(Achievement)
    case showSwapExercise(Exercise)
    case workoutSuccessfullyFinished
    
    // Упрощенная проверка на равенство для SwiftUI .onChange
    static func == (lhs: WorkoutDetailEvent, rhs: WorkoutDetailEvent) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}

@Observable
@MainActor
final class WorkoutDetailViewModel {
    
    // MARK: - Business Data
    var aiCoach: InWorkoutAICoachViewModel
    var workoutAnalytics = WorkoutAnalyticsDataDTO()
    
    // Локальные кэши
    var personalRecordsCache: [String: Double] = [:]
    var lastPerformancesCache: [String: Exercise] = [:]
    var newlyAddedSetId: UUID? = nil
    
    // MARK: - UI State & Events
    /// Текущее активное событие для View
    var activeEvent: WorkoutDetailEvent? = nil
    
    // Состояние Снекбара (Отмена завершения тренировки)
    var isShowingSnackbar: Bool = false
    @ObservationIgnored private var finishWorkoutTask: Task<Void, Never>? = nil
    
    // MARK: - Services
    private let workoutService: WorkoutService
    private let analyticsService: AnalyticsService
    private let exerciseCatalogService: ExerciseCatalogService

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
    
    // MARK: - Data Loading
    
    func loadCaches(from dashboard: DashboardViewModel) {
        self.personalRecordsCache = dashboard.personalRecordsCache
        self.lastPerformancesCache = dashboard.lastPerformancesCache
    }
    
    func updateWorkoutAnalytics(for workout: Workout) {
        let workoutID = workout.persistentModelID
        Task {
            if let analytics = try? await analyticsService.fetchWorkoutAnalytics(workoutID: workoutID) {
                await MainActor.run { self.workoutAnalytics = analytics }
            }
        }
    }
    
    // MARK: - Set & Exercise Management
    
    func addSet(to exercise: Exercise) {
        let lastSet = exercise.sortedSets.last
        let newIndex = (lastSet?.index ?? 0) + 1
        
        Task {
            await workoutService.addSet(
                to: exercise,
                index: newIndex,
                weight: lastSet?.weight,
                reps: lastSet?.reps,
                distance: lastSet?.distance,
                time: lastSet?.time,
                type: .normal,
                isCompleted: false
            )
            await MainActor.run {
                self.newlyAddedSetId = exercise.setsList.last?.id
            }
        }
    }
    
    func removeSet(withId id: UUID, from exercise: Exercise) {
        if let setToDelete = exercise.setsList.first(where: { $0.id == id }) {
            Task { await workoutService.deleteSet(setToDelete, from: exercise) }
        }
    }
    
    func removeExercise(_ exercise: Exercise, from workout: Workout) {
        Task { await workoutService.removeExercise(exercise, from: workout) }
    }
    
    func addExercise(_ newExercise: Exercise, workout: Workout, scrollToExerciseId: @escaping (UUID) -> Void) {
        withAnimation { workout.exercises.insert(newExercise, at: 0) }
        
        // Микро-задержка для UI обновления перед скроллом
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            scrollToExerciseId(newExercise.id)
        }
    }

    func performSwap(old: Exercise, new: Exercise, workout: Workout) {
        guard let index = workout.exercises.firstIndex(where: { $0.id == old.id }) else { return }
        withAnimation {
            workout.exercises.insert(new, at: index)
            Task { await workoutService.removeExercise(old, from: workout) }
        }
        updateWorkoutAnalytics(for: workout)
    }
    
    func deleteEmptyWorkout(workout: Workout) async {
        await workoutService.deleteWorkout(workout)
    }
    
    // MARK: - Workout Flow Logic
    
    func startTimerIfNeeded(shouldStartTimer: Bool, suggestedDuration: Int?) {
        guard shouldStartTimer else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("ForceStartRestTimer"),
            object: nil,
            userInfo: ["duration": suggestedDuration as Any]
        )
    }
    
    func handleSetCompleted(set: WorkoutSet, isLast: Bool, exerciseName: String, workout: Workout, weightUnit: String) {
        Task {
            await aiCoach.triggerProactiveFeedback(
                for: set,
                isLastSet: isLast,
                isPR: false,
                prLevel: nil,
                in: exerciseName,
                currentWorkout: workout,
                weightUnit: weightUnit
            )
        }
    }

    func handleExerciseFinished(exerciseId: UUID, workout: Workout, weightUnit: String, onExpandNext: @escaping (UUID) -> Void) {
        guard let exercise = workout.exercises.first(where: { $0.id == exerciseId }) else { return }
        let exerciseIndex = workout.exercises.firstIndex(of: exercise) ?? 0

        if exercise.isSuperset {
            finishSuperset(exercise, workout: workout, weightUnit: weightUnit)
        } else {
            finishExercise(exercise, workout: workout, weightUnit: weightUnit)
        }

        if let nextIndex = workout.exercises.indices.first(where: { $0 > exerciseIndex && !workout.exercises[$0].isCompleted }) {
            onExpandNext(workout.exercises[nextIndex].id)
        }
    }
    
    private func finishExercise(_ exercise: Exercise, workout: Workout, weightUnit: String) {
        guard !exercise.isCompleted && workout.isActive else { return }
        
        let uncompletedSets = exercise.setsList.filter { !$0.isCompleted }
        if !uncompletedSets.isEmpty {
            Task { await workoutService.deleteSets(uncompletedSets, from: exercise) }
        }
        
        exercise.isCompleted = true
        
        if let prLevel = calculatePRLevel(for: exercise, prCache: self.personalRecordsCache) {
            handlePRSet(level: prLevel, exerciseName: exercise.name, workout: workout, weightUnit: weightUnit)
        }
    }
        
    private func finishSuperset(_ superset: Exercise, workout: Workout, weightUnit: String) {
        guard !superset.isCompleted && workout.isActive else { return }
        
        for sub in superset.subExercises {
            let uncompleted = sub.setsList.filter { !$0.isCompleted }
            if !uncompleted.isEmpty {
                Task { await workoutService.deleteSets(uncompleted, from: sub) }
            }
            sub.isCompleted = true
        }
        
        superset.isCompleted = true
   
        var highestPR: PRLevel? = nil
        for sub in superset.subExercises {
            if let pr = calculatePRLevel(for: sub, prCache: self.personalRecordsCache) {
                if highestPR == nil || pr.rank > highestPR!.rank { highestPR = pr }
            }
        }
        
        if let pr = highestPR {
            handlePRSet(level: pr, exerciseName: superset.name, workout: workout, weightUnit: weightUnit)
        }
    }
    
    private func handlePRSet(level: PRLevel, exerciseName: String, workout: Workout, weightUnit: String) {
        self.activeEvent = .showPR(level)
        Task {
            await self.aiCoach.triggerProactiveFeedback(for: nil, isLastSet: false, isPR: true, prLevel: level.title, in: exerciseName, currentWorkout: workout, weightUnit: weightUnit)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func generateAndShare(workout: Workout) {
        let renderer = ImageRenderer(content: WorkoutShareCard(workout: workout))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            self.activeEvent = .showShareSheet(uiImage)
        }
    }
    
    // MARK: - Finish Workout (Snackbar Flow)
    
    func requestFinishWorkout(workout: Workout, progressManager: ProgressManager) {
        // 1. Проверка на наличие завершенных сетов
        let hasAnyCompletedSet = workout.exercises.contains { exercise in
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            return targets.contains { sub in sub.setsList.contains { $0.isCompleted } }
        }
        
        guard hasAnyCompletedSet else {
            self.activeEvent = .showEmptyAlert
            return
        }
        
        // 2. Временная заморозка (UI показывает что тренировка завершена)
        workout.endTime = Date()
        
        withAnimation {
            self.isShowingSnackbar = true
        }
        
        // 3. Запуск отменяемой задачи таймера
        finishWorkoutTask?.cancel()
        finishWorkoutTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            
            // Если задачу не отменили кнопкой Undo — коммитим в базу
            guard !Task.isCancelled else { return }
            await commitFinishWorkout(workout: workout, progressManager: progressManager)
        }
    }
    
    func undoFinishWorkout(workout: Workout) {
        finishWorkoutTask?.cancel()
        finishWorkoutTask = nil
        
        withAnimation {
            self.isShowingSnackbar = false
        }
        // Возвращаем статус "Активна"
        workout.endTime = nil
    }
    
    private func commitFinishWorkout(workout: Workout, progressManager: ProgressManager) async {
        withAnimation {
            self.isShowingSnackbar = false
        }
        
        progressManager.addXP(for: workout)
        NotificationCenter.default.post(name: .workoutCompletedEvent, object: workout.persistentModelID, userInfo: ["modelContainer": analyticsService.modelContainer])
        
        let workoutID = workout.persistentModelID
        
        if let result = try? await analyticsService.finishWorkoutAndCalculateAchievements(workoutID: workoutID) {
            // Эмитим финальное событие для View (чтобы обновить Dashboard и т.д.)
            self.activeEvent = .workoutSuccessfullyFinished
            
            if let firstUnlock = result.newUnlocks.first {
                // Если есть ачивка, показываем её с небольшой задержкой
                try? await Task.sleep(for: .seconds(0.5))
                self.activeEvent = .showAchievement(firstUnlock)
            }
        }
    }
    
    // MARK: - Math Logic
    
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
