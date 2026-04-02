//
//  CatalogViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 1.04.26.
//


internal import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class CatalogViewModel {
    
    // @Published удалено
    var customExercises: [CustomExerciseDefinition] = []
    var deletedDefaultExercises: Set<String> = []
    
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    var combinedCatalog: [String: [String]] {
        var catalog = Exercise.catalog
        for (category, exercises) in catalog {
            catalog[category] = exercises.filter { !deletedDefaultExercises.contains($0) }
        }
        for custom in customExercises {
            var list = catalog[custom.category] ?? []
            if !list.contains(custom.name) { list.append(custom.name) }
            catalog[custom.category] = list
        }
        return catalog
    }
    
    func loadDictionary() {
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            let custom = (try? await repository.fetchCustomExercises()) ?? []
            let deleted = (try? await repository.fetchDeletedDefaultExercises()) ?? []
            
            await MainActor.run {
                self.customExercises = custom
                self.deletedDefaultExercises = deleted
            }
        }
    }
    
    func isCustomExercise(name: String) -> Bool {
        customExercises.contains { $0.name == name }
    }
    
    func addCustomExercise(name: String, category: String, muscles: [String], type: ExerciseType = .strength) {
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.addCustomExercise(name: name, category: category, muscles: muscles, type: type)
            await MainActor.run {
                MuscleMapping.updateCustomMapping(name: name, muscles: muscles)
                self.loadDictionary()
            }
        }
    }
    
    func deleteCustomExercise(name: String, category: String) {
        Task {
            let repository = WorkoutRepository(modelContainer: modelContainer)
            try? await repository.deleteCustomExercise(name: name, category: category)
            await MainActor.run {
                MuscleMapping.updateCustomMapping(name: name, muscles: nil)
                self.loadDictionary()
            }
        }
    }
    
    func deleteExercise(name: String, category: String) {
        if isCustomExercise(name: name) {
            deleteCustomExercise(name: name, category: category)
        } else {
            Task {
                let repository = WorkoutRepository(modelContainer: modelContainer)
                try? await repository.hideDefaultExercise(name: name, category: category)
                await MainActor.run { self.loadDictionary() }
            }
        }
    }
}
