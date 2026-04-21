import Foundation
import SwiftData

actor ExerciseCatalogService {
    private let catalogRepository: CatalogRepositoryProtocol 
    private let workoutStore: WorkoutStoreProtocol 

    init(catalogRepository: CatalogRepositoryProtocol, workoutStore: WorkoutStoreProtocol) {
        self.catalogRepository = catalogRepository
        self.workoutStore = workoutStore
    }

    func fetchCustomExercises() async throws -> [CustomExerciseDefinition] {
        return try await catalogRepository.fetchCustomExercises()
    }

    func fetchDeletedDefaultExercises() async throws -> Set<String> {
        return try await catalogRepository.fetchDeletedDefaultExercises()
    }

    func addCustomExercise(name: String, category: String, muscles: [String], type: ExerciseType) async throws {
        try await catalogRepository.addCustomExercise(name: name, category: category, targetedMuscles: muscles, type: type)
    }

    func deleteCustomExercise(name: String, category: String) async throws {
        try await catalogRepository.deleteCustomExercise(name: name, category: category)
    }

    func hideDefaultExercise(name: String, category: String) async throws {
        try await catalogRepository.hideDefaultExercise(name: name, category: category)
    }

    func checkAndGenerateDefaultPresets() async throws {
        try await workoutStore.checkAndGenerateDefaultPresets()
    }
}
