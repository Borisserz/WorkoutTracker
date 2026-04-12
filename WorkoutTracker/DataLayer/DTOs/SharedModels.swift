// ============================================================
// FILE: WorkoutTracker/DataLayer/DTOs/SharedModels.swift
// (Используется и в iOS, и в WatchOS таргетах)
// ============================================================
import Foundation

enum SyncActionType: String, Codable, Sendable {
    case startWorkout
    case logSet
    case addExercise
    case updateEffort
    case finishWorkout
    case discardWorkout
    case requestActiveState
    case syncFullState
    case saveToHistory
}

struct LiveSyncPayload: Codable, Sendable {
    let action: SyncActionType
    let workoutID: String
    let workoutTitle: String?
    
    let exerciseName: String?
    let setIndex: Int?
    let weight: Double?
    let reps: Int?
    let effort: Int?
    let isCompleted: Bool?
    
    let exercises: [ExerciseDTO]?
    let activeEnergy: Double?
    let durationSeconds: Int?
    
    init(
        action: SyncActionType,
        workoutID: String,
        workoutTitle: String? = nil,
        exerciseName: String? = nil,
        setIndex: Int? = nil,
        weight: Double? = nil,
        reps: Int? = nil,
        effort: Int? = nil,
        isCompleted: Bool? = nil,
        exercises: [ExerciseDTO]? = nil,
        activeEnergy: Double? = nil,
        durationSeconds: Int? = nil
    ) {
        self.action = action
        self.workoutID = workoutID
        self.workoutTitle = workoutTitle
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.effort = effort
        self.isCompleted = isCompleted
        self.exercises = exercises
        self.activeEnergy = activeEnergy
        self.durationSeconds = durationSeconds
    }
}
