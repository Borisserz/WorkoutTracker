// ============================================================
// FILE: WorkoutTracker/DataLayer/Models/AIChatModels.swift
// ============================================================

import Foundation
import SwiftData

// MARK: - AI Data Transfer Objects (DTOs)

public enum AIActionType: String, Codable, Sendable {
    case dropWeight, addSet, replaceExercise, skipExercise, reduceRemainingLoad, none, unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = AIActionType(rawValue: rawValue) ?? .unknown
    }
}

public struct InWorkoutResponseDTO: Codable, Sendable {
    let explanation: String
    let actionType: AIActionType
    let targetExerciseName: String?
    let valuePercentage: Double?
    let valueReps: Int?
    let valueWeightKg: Double?
    let replacementExerciseName: String?
}

public struct GeneratedWorkoutDTO: Codable, Sendable {
    let title: String
    let aiMessage: String
    let exercises: [GeneratedExerciseDTO]
}

public struct GeneratedExerciseDTO: Codable, Sendable {
    let name: String
    let muscleGroup: String
    let type: String
    let sets: Int
    let reps: Int
    let recommendedWeightKg: Double?
    let restSeconds: Int?
}

public struct AICoachResponseDTO: Sendable {
    let text: String
    let workout: GeneratedWorkoutDTO?
}

public struct UserProfileContext: Codable, Sendable {
    let weightKg: Double
    let experienceLevel: String
    let favoriteMuscles: [String]
    let recentPRs: [String: Double]
    let language: String
    let workoutsThisWeek: Int
    let currentStreak: Int
    let fatiguedMuscles: [String]
    let availableExercises: [String]
    let aiCoachTone: String
    let weightUnit: String
}

// MARK: - SwiftData Models

@Model
final class AIChatSession {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var messages: [AIChatMessage] = []
    
    init(id: UUID = UUID(), title: String = "New Chat", date: Date = Date(), messages: [AIChatMessage] = []) {
        self.id = id
        self.title = title
        self.date = date
        self.messages = messages
    }
}

struct AIChatMessage: Identifiable, Equatable, Codable, Sendable {
    var id = UUID()
    let isUser: Bool
    let text: String
    let proposedWorkout: GeneratedWorkoutDTO?
    var isAnimating: Bool = false
    
    enum CodingKeys: String, CodingKey { case id, isUser, text, proposedWorkout }
    
    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool { lhs.id == rhs.id }
}

public struct GeneratedProgramDTO: Codable, Sendable {
    let title: String
    let description: String
    let durationWeeks: Int
    let schedule: [GeneratedRoutineDTO]
}

public struct GeneratedRoutineDTO: Codable, Sendable {
    let dayName: String
    let focus: String
    let exercises: [GeneratedExerciseDTO]
}
