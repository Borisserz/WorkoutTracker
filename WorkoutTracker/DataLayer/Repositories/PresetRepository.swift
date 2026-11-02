import Foundation
import SwiftData

protocol PresetRepositoryProtocol: Sendable {
    func createPreset(name: String, icon: String, folderName: String?, exercises: [ExerciseDTO]) async throws
    func updatePreset(presetID: PersistentIdentifier, name: String, icon: String, folderName: String?, exercises: [ExerciseDTO]) async throws
    func deletePreset(presetID: PersistentIdentifier) async throws
    func fetchPresetDTO(by id: PersistentIdentifier) async throws -> WorkoutPresetDTO?
    func isProgramSaved(title: String, isSingleRoutine: Bool) async throws -> Bool
    func deletePresets(inFolder folderName: String) async throws
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

        for oldEx in existingPreset.exercises { modelContext.delete(oldEx) }
        existingPreset.exercises.removeAll()

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

    func fetchPresetDTO(by id: PersistentIdentifier) async throws -> WorkoutPresetDTO? {
        guard let preset = modelContext.model(for: id) as? WorkoutPreset else { return nil }
        return preset.toDTO()
    }

    func isProgramSaved(title: String, isSingleRoutine: Bool) async throws -> Bool {
        let targetFolder = isSingleRoutine ? "Saved Routines" : title
        let descriptor = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.folderName == targetFolder })
        let presets = (try? modelContext.fetch(descriptor)) ?? []
        if isSingleRoutine {
            return presets.contains { $0.name == title }
        } else {
            return !presets.isEmpty
        }
    }

    func deletePresets(inFolder folderName: String) async throws {
        guard !folderName.isEmpty else { return }
        let descriptor = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.folderName == folderName })
        let presets = (try? modelContext.fetch(descriptor)) ?? []
        for preset in presets {
            modelContext.delete(preset)
        }
        try modelContext.save()
    }
}
