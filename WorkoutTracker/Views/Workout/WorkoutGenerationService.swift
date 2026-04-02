//
//  WorkoutGenerationService.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2.04.26.
//

//
//  WorkoutGenerationService.swift
//  WorkoutTracker
//

import Foundation

/// Сервис, отвечающий за чистую бизнес-логику генерации тренировок
struct WorkoutGenerationService: Sendable {
    
    /// Маппинг названий групп мышц из рекавери в ключи каталога
    private static func mapRecoveryNameToCatalogKey(_ name: String) -> String {
        switch name {
        case "Chest": return "Chest"
        case "Back", "Lower Back", "Lats", "Traps": return "Back"
        case "Shoulders", "Deltoids": return "Shoulders"
        case "Biceps", "Triceps", "Forearms", "Arms": return "Arms"
        case "Abs", "Core", "Obliques": return "Core"
        case "Legs", "Glutes", "Hamstrings", "Quads", "Calves": return "Legs"
        default: return "Other"
        }
    }
    
    /// Генерирует тренировку на основе восстановившихся мышц
    static func generateFreshWorkout(
        recoveryStatus: [MuscleRecoveryStatus],
        catalog: [String: [String]]
    ) throws -> GeneratedWorkout {
        
        let freshMuscles = recoveryStatus
            .filter { $0.recoveryPercentage >= 90 }
            .map { $0.muscleGroup }
        
        guard !freshMuscles.isEmpty else {
            throw WorkoutGenerationError.tooTired
        }
        
        let selectedMuscles = Array(freshMuscles.shuffled().prefix(2))
        var generatedExercises: [Exercise] = []
        
        for muscle in selectedMuscles {
            let catalogKey = mapRecoveryNameToCatalogKey(muscle)
            if let availableExercises = catalog[catalogKey] {
                let pickedNames = Array(availableExercises.shuffled().prefix(2))
                
                for name in pickedNames {
                    // Создаем модели только в памяти
                    let newEx = Exercise(name: name, muscleGroup: catalogKey, type: .strength, sets: 3, reps: 10, weight: 0.0, effort: 5)
                    generatedExercises.append(newEx)
                }
            }
        }
        
        guard !generatedExercises.isEmpty else {
            throw WorkoutGenerationError.noExercisesFound
        }
        
        let workoutName = "Fresh: " + selectedMuscles.joined(separator: " & ")
        return GeneratedWorkout(title: workoutName, exercises: generatedExercises)
    }
}

enum WorkoutGenerationError: LocalizedError {
    case tooTired
    case noExercisesFound
    
    var errorDescription: String? {
        switch self {
        case .tooTired:
            return String(localized: "You don't have enough fully recovered muscles. Take a rest day or do light cardio!")
        case .noExercisesFound:
            return String(localized: "Could not find suitable exercises in the catalog.")
        }
    }
}
