//
//  UserGoal.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 6.04.26.
//

import Foundation
 import SwiftData

public enum GoalType: String, Codable, Sendable, CaseIterable {
    case strength = "Strength"
    case bodyweight = "Bodyweight"
    case consistency = "Consistency"
}

@Model
final class UserGoal {
    var id: UUID = UUID()
    var typeRawValue: String = GoalType.strength.rawValue
    
    var targetValue: Double = 0.0
    var startingValue: Double = 0.0
    var targetDate: Date = Date()
    
    var exerciseName: String? = nil
    var targetReps: Int = 1
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    
    var type: GoalType {
        get { GoalType(rawValue: typeRawValue) ?? .strength }
        set { typeRawValue = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), type: GoalType, targetValue: Double, startingValue: Double, targetDate: Date, exerciseName: String? = nil, targetReps: Int = 1) {
           self.id = id
           self.typeRawValue = type.rawValue
           self.targetValue = targetValue
           self.startingValue = startingValue
           self.targetDate = targetDate
           self.exerciseName = exerciseName
           self.targetReps = targetReps
           self.isCompleted = false
           self.createdAt = Date()
       }
   }
