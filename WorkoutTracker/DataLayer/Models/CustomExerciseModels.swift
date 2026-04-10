// ============================================================
// FILE: WorkoutTracker/DataLayer/Models/CustomExerciseModels.swift
// ============================================================
import Foundation
import SwiftData

@Model
class ExerciseDictionaryItem {
    var name: String = ""
    var category: String = ""
    var targetedMuscles: [String] = []
    var type: ExerciseType = ExerciseType.strength
    var isCustom: Bool = false
    var isHidden: Bool = false
    
    init(name: String = "", category: String = "", targetedMuscles: [String] = [], type: ExerciseType = .strength, isCustom: Bool = false, isHidden: Bool = false) {
        self.name = name; self.category = category; self.targetedMuscles = targetedMuscles; self.type = type; self.isCustom = isCustom; self.isHidden = isHidden
    }
}

struct CustomExerciseDefinition: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var category: String
    var targetedMuscles: [String]
    var type: ExerciseType = .strength
}
