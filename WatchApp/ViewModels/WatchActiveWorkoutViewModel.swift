// ============================================================
// FILE: WatchApp/ViewModels/WatchActiveWorkoutViewModel.swift
// ============================================================
internal import SwiftUI
import Observation
import SwiftData

@Observable
@MainActor
final class WatchActiveWorkoutViewModel {
    let workoutID: UUID
    let workoutTitle: String
    
    // UI стейт (живые данные)
    var exercises: [ExerciseDTO] = []
    
    // Статистика для финального экрана
    var totalVolume: Double = 0.0
    var totalSets: Int = 0
    
    private let store: WatchWorkoutStore
    
    init(workoutID: UUID, workoutTitle: String, presetDTO: WorkoutPresetDTO?, store: WatchWorkoutStore) {
        self.workoutID = workoutID
        self.workoutTitle = workoutTitle
        self.store = store
        
        if let dto = presetDTO {
            self.exercises = dto.exercises
        }
    }
    
    func initializeWorkout() async {
        let payload = LiveSyncPayload(action: .startWorkout, workoutID: workoutID.uuidString, workoutTitle: workoutTitle)
        WatchSyncManager.shared.sendLiveAction(payload)
        
        // Создаем зеркало тренировки в локальной базе часов
        _ = try? await store.startNewWorkout(title: workoutTitle, uuidString: workoutID.uuidString)
    }
    
    func addExercise(name: String) async {
        let newEx = ExerciseDTO(name: name, muscleGroup: "Mixed", type: .strength, category: .other, effort: 5, isCompleted: false, setsList: [], subExercises: [])
        exercises.append(newEx)
        
        let payload = LiveSyncPayload(action: .addExercise, workoutID: workoutID.uuidString, exerciseName: name)
        WatchSyncManager.shared.sendLiveAction(payload)
    }
    
    func logSet(for exerciseIndex: Int, weight: Double, reps: Int) async {
        guard exercises.indices.contains(exerciseIndex) else { return }
        let currentEx = exercises[exerciseIndex]
        let nextIndex = currentEx.setsList.count + 1
        
        WKInterfaceDevice.current().play(.success)
        
        let payload = LiveSyncPayload(
            action: .logSet, workoutID: workoutID.uuidString, exerciseName: currentEx.name,
            setIndex: nextIndex, weight: weight, reps: reps, isCompleted: true
        )
        WatchSyncManager.shared.sendLiveAction(payload)
        
        // Запись в локальную базу
        _ = try? await store.logSet(workoutID: workoutID.uuidString, exerciseName: currentEx.name, weight: weight, reps: reps)
        
        // Обновление UI
        let newSet = WorkoutSetDTO(index: nextIndex, weight: weight, reps: reps, distance: nil, time: nil, isCompleted: true, type: .normal)
        var updatedSets = currentEx.setsList
        updatedSets.append(newSet)
        exercises[exerciseIndex] = ExerciseDTO(name: currentEx.name, muscleGroup: currentEx.muscleGroup, type: currentEx.type, category: currentEx.category, effort: currentEx.effort, isCompleted: currentEx.isCompleted, setsList: updatedSets, subExercises: currentEx.subExercises)
        
        totalSets += 1
        totalVolume += (weight * Double(reps))
    }
    
    func finishWorkout() async {
        _ = try? await store.finishWorkout(workoutID: workoutID.uuidString)
        let payload = LiveSyncPayload(action: .finishWorkout, workoutID: workoutID.uuidString)
        WatchSyncManager.shared.sendLiveAction(payload)
    }
    
    func cancelWorkout() async {
        let payload = LiveSyncPayload(action: .discardWorkout, workoutID: workoutID.uuidString)
        WatchSyncManager.shared.sendLiveAction(payload)
    }
}
