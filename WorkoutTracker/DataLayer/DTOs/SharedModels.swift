
import Foundation

/// WCSession userInfo / message keys for live workout sync.
/// Always write both; always read either — phone and Watch historically disagreed on the key name.
enum WatchSyncEnvelope {
    static let syncPayloadKey = "syncPayload"
    static let guaranteedSyncPayloadKey = "guaranteedSyncPayload"

    static func liveSyncData(from dict: [String: Any]) -> Data? {
        if let data = dict[syncPayloadKey] as? Data { return data }
        if let data = dict[guaranteedSyncPayloadKey] as? Data { return data }
        return nil
    }

    /// Outbound dictionary accepted by both phone and Watch receivers.
    static func userInfo(carrying data: Data) -> [String: Any] {
        [syncPayloadKey: data, guaranteedSyncPayloadKey: data]
    }
}

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
    case updateHeartRate
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
    let heartRate: Double?
    /// Watch already called `HKLiveWorkoutBuilder.finishWorkout()`. Phone must not write a second Health workout.
    let healthKitSavedOnWatch: Bool?
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
        durationSeconds: Int? = nil,
        heartRate: Double? = nil,
        healthKitSavedOnWatch: Bool? = nil
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
        self.heartRate = heartRate
        self.healthKitSavedOnWatch = healthKitSavedOnWatch
    }
}
