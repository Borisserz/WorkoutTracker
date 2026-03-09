//
//  CustomExerciseModels.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

import Foundation
import SwiftData

// Единая таблица-словарь для кастомных и скрытых упражнений в SwiftData
@Model
class ExerciseDictionaryItem {
    @Attribute(.unique) var name: String
    var category: String
    var targetedMuscles: [String]
    var type: ExerciseType
    var isCustom: Bool
    var isHidden: Bool
    
    init(name: String, category: String, targetedMuscles: [String] = [], type: ExerciseType = .strength, isCustom: Bool = false, isHidden: Bool = false) {
        self.name = name
        self.category = category
        self.targetedMuscles = targetedMuscles
        self.type = type
        self.isCustom = isCustom
        self.isHidden = isHidden
    }
}

// Оставляем структуру для UI-слоя (кэширования), чтобы не переписывать логику Views
struct CustomExerciseDefinition: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var category: String
    var targetedMuscles: [String]
    var type: ExerciseType = .strength
}
