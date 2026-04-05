// ============================================================
// FILE: WatchApp/DataLayer/WatchWorkoutStore.swift
// ============================================================
import Foundation
import SwiftData

@ModelActor
actor WatchWorkoutStore {
    
    func startNewWorkout(title: String, uuidString: String) throws -> PersistentIdentifier {
        guard let id = UUID(uuidString: uuidString) else { throw WorkoutRepositoryError.invalidData }
        let workout = Workout(id: id, title: title, date: Date(), exercises: [])
        workout.icon = "applewatch"
        modelContext.insert(workout)
        try modelContext.save()
        return workout.persistentModelID
    }
    
    func logSet(workoutID: String, exerciseName: String, weight: Double, reps: Int) throws {
        // Ищем тренировку по ID
        let desc = FetchDescriptor<Workout>()
        guard let allWorkouts = try? modelContext.fetch(desc),
              let workout = allWorkouts.first(where: { $0.id.uuidString == workoutID }) else { return }
        
        // Находим или создаем упражнение
        let exercise: Exercise
        if let existing = workout.exercises.first(where: { $0.name == exerciseName && !$0.isCompleted }) {
            exercise = existing
        } else {
            exercise = Exercise(name: exerciseName, muscleGroup: "Mixed", type: .strength, sets: 0, reps: 0, weight: 0)
            modelContext.insert(exercise)
            workout.exercises.append(exercise)
            exercise.workout = workout
        }
        
        let nextIndex = (exercise.setsList.max(by: { $0.index < $1.index })?.index ?? 0) + 1
        let newSet = WorkoutSet(index: nextIndex, weight: weight, reps: reps, isCompleted: true, type: .normal)
        
        modelContext.insert(newSet)
        exercise.setsList.append(newSet)
        newSet.exercise = exercise
        
        try modelContext.save()
    }
    
    func finishWorkout(workoutID: String) throws {
        let desc = FetchDescriptor<Workout>()
        guard let allWorkouts = try? modelContext.fetch(desc),
              let workout = allWorkouts.first(where: { $0.id.uuidString == workoutID }) else { return }
        
        workout.endTime = Date()
        workout.durationSeconds = Int(workout.endTime!.timeIntervalSince(workout.date))
        for ex in workout.exercises { ex.isCompleted = true }
        try modelContext.save()
    }
}
