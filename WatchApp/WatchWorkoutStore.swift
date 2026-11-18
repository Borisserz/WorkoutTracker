
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

    func logSet(workoutID: String, exerciseName: String, setIndex: Int, weight: Double, reps: Int) throws {
        guard let workout = try workout(forID: workoutID) else { return }

        let exercise: Exercise
        if let existing = workout.exercises.first(where: { $0.name == exerciseName && !$0.isCompleted })
            ?? workout.exercises.first(where: { $0.name == exerciseName }) {
            exercise = existing
        } else {
            exercise = Exercise(name: exerciseName, muscleGroup: "Mixed", type: .strength, sets: 0, reps: 0, weight: 0)
            modelContext.insert(exercise)
            workout.exercises.append(exercise)
            exercise.workout = workout
        }

        if let existingSet = exercise.setsList.first(where: { $0.index == setIndex }) {
            existingSet.weight = weight
            existingSet.reps = reps
            existingSet.isCompleted = true
        } else {
            let newSet = WorkoutSet(index: setIndex, weight: weight, reps: reps, isCompleted: true, type: .normal)
            modelContext.insert(newSet)
            exercise.setsList.append(newSet)
            newSet.exercise = exercise
        }

        try modelContext.save()
    }

    func finishWorkout(workoutID: String) throws {
        guard let workout = try workout(forID: workoutID) else { return }

        workout.endTime = Date()
        workout.durationSeconds = Int(workout.endTime!.timeIntervalSince(workout.date))
        for ex in workout.exercises { ex.isCompleted = true }
        try modelContext.save()
    }

    func updateExerciseEffort(workoutID: String, exerciseName: String, effort: Int) throws {
        guard let workout = try workout(forID: workoutID),
              let exercise = workout.exercises.first(where: { $0.name == exerciseName && !$0.isCompleted }) else { return }

        exercise.effort = effort
        try modelContext.save()
    }

    func discardWorkout(workoutID: String) throws {
        guard let workout = try workout(forID: workoutID) else { return }
        modelContext.delete(workout)
        try modelContext.save()
    }

    func addExercise(workoutID: String, exerciseName: String) throws {
        guard let workout = try workout(forID: workoutID),
              !workout.exercises.contains(where: { $0.name == exerciseName }) else { return }
        let ex = Exercise(name: exerciseName, muscleGroup: "Mixed", type: .strength, sets: 3, reps: 10, weight: 0)
        modelContext.insert(ex)
        for set in ex.setsList { modelContext.insert(set) }
        ex.workout = workout
        workout.exercises.append(ex)
        try modelContext.save()
    }

    func addSet(workoutID: String, exerciseName: String, setIndex: Int) throws {
        guard let workout = try workout(forID: workoutID),
              let ex = workout.exercises.first(where: { $0.name == exerciseName }) else { return }
        guard !ex.setsList.contains(where: { $0.index == setIndex }) else { return }
        let newSet = WorkoutSet(index: setIndex, weight: nil, reps: nil, isCompleted: false, type: .normal)
        modelContext.insert(newSet)
        newSet.exercise = ex
        ex.setsList.append(newSet)
        try modelContext.save()
    }

    func removeSet(workoutID: String, exerciseName: String, setIndex: Int) throws {
        guard let workout = try workout(forID: workoutID),
              let ex = workout.exercises.first(where: { $0.name == exerciseName }) else { return }
        let toDelete = ex.setsList.filter { $0.index == setIndex }
        for s in toDelete {
            ex.setsList.removeAll { $0.persistentModelID == s.persistentModelID }
            modelContext.delete(s)
        }
        let sorted = ex.setsList.sorted { $0.index < $1.index }
        for (offset, s) in sorted.enumerated() { s.index = offset + 1 }
        try modelContext.save()
    }

    func removeExercise(workoutID: String, exerciseName: String) throws {
        guard let workout = try workout(forID: workoutID),
              let idx = workout.exercises.firstIndex(where: { $0.name == exerciseName }) else { return }
        let ex = workout.exercises.remove(at: idx)
        modelContext.delete(ex)
        try modelContext.save()
    }

    private func workout(forID workoutID: String) throws -> Workout? {
        guard let id = UUID(uuidString: workoutID) else { return nil }
        var desc = FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.id == id })
        desc.fetchLimit = 1
        return try modelContext.fetch(desc).first
    }

}
