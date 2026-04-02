//
//  ExerciseCatalogService.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2.04.26.
//

import Foundation
import SwiftData

actor ExerciseCatalogService {
    private let workoutStore: WorkoutStoreProtocol
    
    init(workoutStore: WorkoutStoreProtocol) {
        self.workoutStore = workoutStore
    }
    
    func fetchCustomExercises() async throws -> [CustomExerciseDefinition] {
        return try await workoutStore.fetchCustomExercises()
    }
    
    func fetchDeletedDefaultExercises() async throws -> Set<String> {
        return try await workoutStore.fetchDeletedDefaultExercises()
    }
    
    func addCustomExercise(name: String, category: String, muscles: [String], type: ExerciseType) async throws {
        try await workoutStore.addCustomExercise(name: name, category: category, targetedMuscles: muscles, type: type)
    }
    
    func deleteCustomExercise(name: String, category: String) async throws {
        try await workoutStore.deleteCustomExercise(name: name, category: category)
    }
    
    func hideDefaultExercise(name: String, category: String) async throws {
        try await workoutStore.hideDefaultExercise(name: name, category: category)
    }
    
    func checkAndGenerateDefaultPresets() async throws {
        try await workoutStore.checkAndGenerateDefaultPresets()
    }
}
