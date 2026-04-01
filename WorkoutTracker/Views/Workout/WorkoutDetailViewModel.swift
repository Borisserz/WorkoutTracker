//
//  WorkoutDetailViewModel 2.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 31.03.26.
//
internal import SwiftUI
import SwiftData
import Charts
import Combine
import ActivityKit
internal import UniformTypeIdentifiers

// MARK: - Dedicated ViewModel for Detail View (CLEAN MVVM)
@MainActor
final class WorkoutDetailViewModel: ObservableObject {
    @Published var showShareSheet = false
    @Published var showEmptyWorkoutAlert = false
    @Published var showPRCelebration = false
    @Published var prLevel: PRLevel = .bronze
    @Published var newlyUnlockedAchievement: Achievement?
    
    @Published var snackbarMessage: LocalizedStringKey?
    @Published var shareItems: [UIImage] = []
    
    private var snackbarCommitAction: (() -> Void)?
    private var snackbarUndoAction: (() -> Void)?
    private var snackbarTask: Task<Void, Never>?
    
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
    
    func generateAndShare(workout: Workout) {
        let renderer = ImageRenderer(content: WorkoutShareCard(workout: workout))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            self.shareItems = [uiImage]
            self.showShareSheet = true
        }
    }
    
    func finishWorkout(workout: Workout, timerManager: RestTimerManager, viewModel: WorkoutViewModel, tutorialManager: TutorialManager, updateAchievementsCount: @escaping (Int) -> Int) {
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
            
            // ИСПРАВЛЕНИЕ: Явно указываем тип замыкания, чтобы Swift не вывел тип () -> Void?
            let commitAction: () -> Void = { [weak self] in
                self?.executeFinishWorkoutBackend(
                    workout: workout,
                    viewModel: viewModel,
                    tutorialManager: tutorialManager,
                    updateAchievementsCount: updateAchievementsCount
                )
            }
            
            executeWithUndo(
                message: "Workout finished",
                optimisticUpdate: {
                    workout.endTime = Date()
                    timerManager.stopRestTimer()
                },
                commit: commitAction,
                undo: {
                    workout.endTime = nil
                }
            )
        }
    
    private func executeFinishWorkoutBackend(workout: Workout, viewModel: WorkoutViewModel, tutorialManager: TutorialManager, updateAchievementsCount: @escaping (Int) -> Int) {
        if tutorialManager.currentStep == .finishWorkout {
            tutorialManager.setStep(.recoveryCheck)
        }
        
        viewModel.progressManager.addXP(for: workout)
        NotificationManager.shared.scheduleNotifications(after: workout)
        
        Task {
               for activity in Activity<WorkoutActivityAttributes>.activities {
                   let finalState = WorkoutActivityAttributes.ContentState(startTime: Date())
                   await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(5)))
               }
           }
        viewModel.finishWorkoutAndCalculateAchievements(workout) { [weak self] newUnlocks, totalCount in
            let oldCount = updateAchievementsCount(totalCount)
            if let firstUnlock = newUnlocks.first {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                self?.newlyUnlockedAchievement = firstUnlock
            } else if totalCount > oldCount {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    // MARK: - Exercise & Superset Completion Logic
        
        /// Завершение одиночного упражнения
        func finishExercise(
            _ exercise: Exercise,
            workout: Workout,
            globalViewModel: WorkoutViewModel,
            tutorialManager: TutorialManager,
            onPRSet: @escaping (PRLevel) -> Void,
            onShowEffort: @escaping () -> Void
        ) {
            guard !exercise.isCompleted && workout.isActive else { return }
            
            // 1. Очистка пустых сетов
            let uncompletedSets = exercise.setsList.filter { !$0.isCompleted }
            for set in uncompletedSets {
                globalViewModel.deleteSet(set, from: exercise)
            }
            
            // 2. Смена статуса
            exercise.isCompleted = true
            
            // 3. Туториал
            if tutorialManager.currentStep == .finishExercise {
                tutorialManager.setStep(.explainEffort)
            }
            
            // 4. Проверка на рекорд
            if let prLevel = calculatePRLevel(for: exercise, globalViewModel: globalViewModel) {
                onPRSet(prLevel)
            } else {
                onShowEffort()
            }
        }
        
        /// Завершение Суперсета
        func finishSuperset(
            _ superset: Exercise,
            workout: Workout,
            globalViewModel: WorkoutViewModel,
            onPRSet: @escaping (PRLevel) -> Void,
            onShowEffort: @escaping () -> Void
        ) {
            guard !superset.isCompleted && workout.isActive else { return }
            
            // 1. Очистка всех вложенных упражнений
            for sub in superset.subExercises {
                let uncompletedSets = sub.setsList.filter { !$0.isCompleted }
                for set in uncompletedSets {
                    globalViewModel.deleteSet(set, from: sub)
                }
                sub.isCompleted = true
            }
            
            superset.isCompleted = true
            superset.updateAggregates()
            
            // 2. Ищем наивысший рекорд среди всех упражнений суперсета
            var highestPR: PRLevel? = nil
            
            for subExercise in superset.subExercises {
                if let pr = calculatePRLevel(for: subExercise, globalViewModel: globalViewModel) {
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
        
        // MARK: - Private Helpers
        
        /// Математика: расчет уровня личного рекорда
        private func calculatePRLevel(for exercise: Exercise, globalViewModel: WorkoutViewModel) -> PRLevel? {
            guard exercise.type == .strength else { return nil }
            
            let maxWeightInWorkout = exercise.setsList
                .filter { $0.isCompleted }
                .compactMap { $0.weight }
                .max() ?? 0.0
            
            let oldRecord = globalViewModel.personalRecordsCache[exercise.name] ?? 0.0
            
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
