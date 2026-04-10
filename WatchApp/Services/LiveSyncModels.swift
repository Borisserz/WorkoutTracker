//
//  LiveSyncModels.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 5.04.26.
//

// ============================================================
// FILE: WatchApp/Models/LiveSyncModels.swift
// ============================================================
import Foundation

public enum SyncActionType: String, Codable, Sendable {
    case startWorkout
    case logSet
    case addExercise
    case finishWorkout
    case discardWorkout
}

public struct LiveSyncPayload: Codable, Sendable {
    public let action: SyncActionType
    public let workoutID: String
    public let workoutTitle: String?
    
    public let exerciseName: String?
    public let setIndex: Int?
    public let weight: Double?
    public let reps: Int?
    public let isCompleted: Bool?
    
    public init(action: SyncActionType, workoutID: String, workoutTitle: String? = nil, exerciseName: String? = nil, setIndex: Int? = nil, weight: Double? = nil, reps: Int? = nil, isCompleted: Bool? = nil) {
        self.action = action
        self.workoutID = workoutID
        self.workoutTitle = workoutTitle
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
    }
}
