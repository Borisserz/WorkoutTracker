

import Foundation
import SwiftData
import Foundation

struct AIPersonasConfig: Codable, Sendable {
    let personas: [AIPersona]
}

struct AIPersona: Codable, Identifiable, Sendable {
    var id: String
    let displayName: String
    let systemInstruction: String
    let notifications: AINotifications
}

struct AINotifications: Codable, Sendable {
    let restTimer: NotificationCopy
    let recovery: NotificationCopy
    let streak: NotificationCopy
    let pr: NotificationCopy
    let inactivity: NotificationCopy
}

struct NotificationCopy: Codable, Sendable {
    let title: String
    let body: String
}
public struct AIWeeklyReviewDTO: Codable, Sendable {
    let weeklyScore: Int
    let title: String
    let topHighlight: String
    let weakPointAlert: String
    let coachAdvice: String
    let coachMood: String 
}

public enum AIActionType: String, Codable, Sendable {
    case dropWeight, addSet, replaceExercise, skipExercise, reduceRemainingLoad, none, unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = AIActionType(rawValue: rawValue) ?? .unknown
    }
}
public struct SmartActionDTO: Codable, Sendable, Equatable {
    let action: String 
    let exerciseName: String
    let setsRemaining: Int
    let weightValue: Double
    let reasoning: String
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
    var text: String 
    let proposedWorkout: GeneratedWorkoutDTO?
    var isAnimating: Bool = false

    enum CodingKeys: String, CodingKey { case id, isUser, text, proposedWorkout }

    init(id: UUID = UUID(), isUser: Bool, text: String, proposedWorkout: GeneratedWorkoutDTO? = nil, isAnimating: Bool = false) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.proposedWorkout = proposedWorkout
        self.isAnimating = isAnimating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.isUser = try container.decode(Bool.self, forKey: .isUser)
        self.text = try container.decode(String.self, forKey: .text)
        self.proposedWorkout = try container.decodeIfPresent(GeneratedWorkoutDTO.self, forKey: .proposedWorkout)
        self.isAnimating = false 
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(isUser, forKey: .isUser)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(proposedWorkout, forKey: .proposedWorkout)
    }

    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool { lhs.id == rhs.id }
}
