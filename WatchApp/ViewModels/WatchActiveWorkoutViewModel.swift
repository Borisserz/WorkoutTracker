// ============================================================
// FILE: WatchApp/ViewModels/WatchActiveWorkoutViewModel.swift
// ============================================================
internal import SwiftUI
import Observation
import SwiftData

@Observable
@MainActor
final class WatchActiveWorkoutViewModel {
    private var restTargetEndTime: Date?
    let workoutID: UUID
    let workoutTitle: String
    
    var exercises: [ExerciseDTO] = []
    var totalVolume: Double = 0.0
    var totalSets: Int = 0
    
    // MARK: - Navigation State
    var showRestTimer = false
    var showRPE = false
    var showSummary = false
    
    // MARK: - Timer & Flow State
    var restTimeRemaining: Int = 60
    var initialRestTime: Int = 60
    var nextSetInfo: String = ""
    var currentExerciseIndexForRPE: Int? = nil
    
    private var restTimerTask: Task<Void, Never>?
    private let store: WatchWorkoutStore
    
    init(workoutID: UUID, workoutTitle: String, presetDTO: WorkoutPresetDTO?, store: WatchWorkoutStore) {
        self.workoutID = workoutID
        self.workoutTitle = workoutTitle
        self.store = store
        if let dto = presetDTO { self.exercises = dto.exercises }
    }
    
    func cleanup() {
        restTimerTask?.cancel()
    }
    
    func initializeWorkout() async {
        let payload = LiveSyncPayload(action: .startWorkout, workoutID: workoutID.uuidString, workoutTitle: workoutTitle)
        WatchSyncManager.shared.sendLiveAction(payload)
        _ = try? await store.startNewWorkout(title: workoutTitle, uuidString: workoutID.uuidString)
    }
    
    func addExercise(name: String) async {
        let newEx = ExerciseDTO(
            name: name,
            muscleGroup: "Mixed",
            type: .strength,
            category: .other,
            effort: 5,
            isCompleted: false,
            setsList: [],
            subExercises: [],
            sets: 3,
            reps: 10,
            recommendedWeightKg: 0.0
        )
        exercises.append(newEx)
        
        let payload = LiveSyncPayload(action: .addExercise, workoutID: workoutID.uuidString, exerciseName: name)
        WatchSyncManager.shared.sendLiveAction(payload)
    }
    
    // MARK: - Set Logging & Flow Routing
    func logSet(for exerciseIndex: Int, weight: Double, reps: Int) async {
        guard exercises.indices.contains(exerciseIndex) else { return }
        var currentEx = exercises[exerciseIndex]
        
        let completedSets = (currentEx.setsList ?? []).count
        let nextIndex = completedSets + 1
        
        // 1. Sync & Save
        WKInterfaceDevice.current().play(.success)
        let payload = LiveSyncPayload(action: .logSet, workoutID: workoutID.uuidString, exerciseName: currentEx.name, setIndex: nextIndex, weight: weight, reps: reps, isCompleted: true)
        WatchSyncManager.shared.sendLiveAction(payload)
        _ = try? await store.logSet(workoutID: workoutID.uuidString, exerciseName: currentEx.name, weight: weight, reps: reps)
        
        // 2. Update Local DTO
        let newSet = WorkoutSetDTO(index: nextIndex, weight: weight, reps: reps, distance: nil, time: nil, isCompleted: true, type: .normal)
        var updatedSets = currentEx.setsList ?? []
        updatedSets.append(newSet)
        currentEx.setsList = updatedSets
        exercises[exerciseIndex] = currentEx
        
        totalSets += 1
        totalVolume += (weight * Double(reps))
        
        // 3. Routing Logic (Timer vs RPE)
        let targetSets = currentEx.sets ?? 3
        let isLastSet = updatedSets.count >= targetSets
        
        if isLastSet {
            currentExerciseIndexForRPE = exerciseIndex
            showRPE = true
        } else {
            // Read default rest time from UserDefaults (Fallback to 60s)
            let defaultRest = UserDefaults.standard.integer(forKey: "defaultRestTime")
            let restDuration = defaultRest > 0 ? defaultRest : 60
            prepareAndStartRestTimer(for: exerciseIndex, nextSetIndex: nextIndex + 1, restDuration: restDuration)
        }
    }
    private func prepareAndStartRestTimer(for exerciseIndex: Int, nextSetIndex: Int, restDuration: Int) {
        let exName = exercises[exerciseIndex].name
        let targetSets = exercises[exerciseIndex].sets ?? 3
        
        nextSetInfo = "Next: \(exName)\nSet \(nextSetIndex)/\(targetSets)"
        initialRestTime = restDuration
        restTimeRemaining = restDuration
        
        // Вычисляем реальное время окончания
        restTargetEndTime = Date().addingTimeInterval(TimeInterval(restDuration))
        showRestTimer = true
        
        restTimerTask?.cancel()
        restTimerTask = Task {
            // Проверяем разницу между текущим временем и целевым
            while let target = restTargetEndTime, target > Date() {
                let diff = Int(target.timeIntervalSinceNow)
                if diff != restTimeRemaining {
                    restTimeRemaining = diff
                }
                // Просыпаемся каждые полсекунды для обновления UI (не блокируя тред)
                try? await Task.sleep(for: .milliseconds(500))
            }
            
            // Timer Finished
            guard !Task.isCancelled else { return }
            WKInterfaceDevice.current().play(.success)
            showRestTimer = false
        }
    }

    func skipTimer() {
        restTimerTask?.cancel()
        restTargetEndTime = nil
        showRestTimer = false
    }

    func adjustTimer(by seconds: Int) {
        guard let currentTarget = restTargetEndTime else { return }
        let newTarget = currentTarget.addingTimeInterval(TimeInterval(seconds))
        
        if newTarget <= Date() {
            skipTimer()
        } else {
            restTargetEndTime = newTarget
            restTimeRemaining = Int(newTarget.timeIntervalSinceNow)
        }
    }

    // ----------------------------------------------------
    // ДОБАВЬ НОВЫЙ МЕТОД ДЛЯ СОХРАНЕНИЯ RPE:
    // ----------------------------------------------------

    // MARK: - RPE Logic
    func saveRPE(_ rpe: Int) async {
        guard let exIndex = currentExerciseIndexForRPE, exercises.indices.contains(exIndex) else { return }
        let exName = exercises[exIndex].name
        
        // 1. Сохраняем локально в SwiftData на часах
        _ = try? await store.updateExerciseEffort(workoutID: workoutID.uuidString, exerciseName: exName, effort: rpe)
        
        // 2. Закрываем экран RPE
        showRPE = false
        currentExerciseIndexForRPE = nil
        
        // Примечание: Для синхронизации RPE с iPhone прямо в реальном времени,
        // потребуется добавить `effort` в LiveSyncPayload.
        // Но так как мы синхронизируем всю тренировку в конце через HealthKit/базу,
        // сейчас достаточно локального сохранения.
    }
    // MARK: - Finish / Cancel
    func finishWorkout() async {
        _ = try? await store.finishWorkout(workoutID: workoutID.uuidString)
        let payload = LiveSyncPayload(action: .finishWorkout, workoutID: workoutID.uuidString)
        WatchSyncManager.shared.sendLiveAction(payload)
        showSummary = true
    }
    
    func cancelWorkout() async {
        let payload = LiveSyncPayload(action: .discardWorkout, workoutID: workoutID.uuidString)
        WatchSyncManager.shared.sendLiveAction(payload)
    }
}
