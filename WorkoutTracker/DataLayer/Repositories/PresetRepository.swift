import Foundation
import SwiftData

protocol PresetRepositoryProtocol: Sendable {
    func fetchPresets(matching descriptor: FetchDescriptor<WorkoutPreset>) async throws -> [WorkoutPreset]
    func createPreset(name: String, icon: String, folderName: String?, exercises: [ExerciseDTO]) async throws
    func updatePreset(presetID: PersistentIdentifier, name: String, icon: String, folderName: String?, exercises: [ExerciseDTO]) async throws
    func deletePreset(presetID: PersistentIdentifier) async throws
    func fetchPreset(by id: PersistentIdentifier) async throws -> WorkoutPreset?
}
@ModelActor
actor PresetRepository: PresetRepositoryProtocol {
    
    func createPreset(name: String, icon: String, folderName: String?, exercises: [ExerciseDTO]) async throws {
        let newPreset = WorkoutPreset(id: UUID(), name: name, icon: icon, folderName: folderName, exercises: [])
        modelContext.insert(newPreset)
        
        for dto in exercises {
            let newEx = Exercise(from: dto)
            modelContext.insert(newEx)
            newEx.preset = newPreset
            newPreset.exercises.append(newEx)
            
            for set in newEx.setsList { modelContext.insert(set) }
            for subEx in newEx.subExercises {
                modelContext.insert(subEx)
                subEx.preset = newPreset
                for set in subEx.setsList { modelContext.insert(set) }
            }
        }
        try modelContext.save()
    }

    func updatePreset(presetID: PersistentIdentifier, name: String, icon: String, folderName: String?, exercises: [ExerciseDTO]) async throws {
        guard let existingPreset = modelContext.model(for: presetID) as? WorkoutPreset else { throw WorkoutRepositoryError.modelNotFound }
        
        existingPreset.name = name
        existingPreset.icon = icon
        if let newFolder = folderName {
            existingPreset.folderName = newFolder
        }
        
        // Очищаем старые упражнения
        for oldEx in existingPreset.exercises { modelContext.delete(oldEx) }
        existingPreset.exercises.removeAll()
        
        // Добавляем новые из DTO
        for dto in exercises {
            let newEx = Exercise(from: dto)
            modelContext.insert(newEx)
            newEx.preset = existingPreset
            existingPreset.exercises.append(newEx)
            
            for set in newEx.setsList { modelContext.insert(set) }
            for subEx in newEx.subExercises {
                modelContext.insert(subEx)
                subEx.preset = existingPreset
                for set in subEx.setsList { modelContext.insert(set) }
            }
        }
        try modelContext.save()
    }
    func deletePreset(presetID: PersistentIdentifier) async throws {
        guard let preset = modelContext.model(for: presetID) as? WorkoutPreset else { throw WorkoutRepositoryError.modelNotFound }
        modelContext.delete(preset)
        try modelContext.save()
    }

    func fetchPreset(by id: PersistentIdentifier) async throws -> WorkoutPreset? {
        return modelContext.model(for: id) as? WorkoutPreset
    }
    func fetchPresets(matching descriptor: FetchDescriptor<WorkoutPreset>) async throws -> [WorkoutPreset] {
            return try modelContext.fetch(descriptor)
        }
}
