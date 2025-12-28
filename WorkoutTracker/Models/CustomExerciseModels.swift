//
//  CustomExerciseModels.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

import Foundation

struct CustomExerciseDefinition: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var category: String      // Например "Chest"
    var targetedMuscles: [String] // Технические слаги: ["chest", "triceps"]
}
