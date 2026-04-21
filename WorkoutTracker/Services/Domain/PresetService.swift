

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class PresetService {

    private let presetRepository: PresetRepositoryProtocol
    private let appState: AppStateManager

    init(presetRepository: PresetRepositoryProtocol, appState: AppStateManager) {
        self.presetRepository = presetRepository
        self.appState = appState
    }

    func savePreset(preset: WorkoutPreset?, name: String, icon: String, folderName: String? = nil, exercises: [Exercise]) async {
          let exerciseDTOs = exercises.map { $0.toDTO() }

          do {
              if let existingPreset = preset {
                  try await presetRepository.updatePreset(
                      presetID: existingPreset.persistentModelID,
                      name: name,
                      icon: icon,
                      folderName: folderName ?? existingPreset.folderName,
                      exercises: exerciseDTOs
                  )
              } else {
                  try await presetRepository.createPreset(
                      name: name,
                      icon: icon,
                      folderName: folderName,
                      exercises: exerciseDTOs
                  )
              }
          } catch {
              appState.showError(title: "Save Failed", message: "Failed to save template: \(error.localizedDescription)")
          }
      }

    func deletePreset(_ preset: WorkoutPreset) async {
        do {
            try await presetRepository.deletePreset(presetID: preset.persistentModelID)
        } catch {
            appState.showError(title: "Delete Failed", message: "Failed to delete template: \(error.localizedDescription)")
        }
    }

    func generateShareLink(for preset: WorkoutPreset) throws -> URL {
        return try WorkoutExportService.generateShareLink(for: preset.toDTO())
    }

    func exportPresetToFile(_ preset: WorkoutPreset) async throws -> URL {
        guard let fetchedPreset = try await presetRepository.fetchPreset(by: preset.persistentModelID) else {
            throw WorkoutRepositoryError.modelNotFound
        }
        return try WorkoutExportService.exportPresetToFile(fetchedPreset.toDTO())
    }

    func exportPresetToCSV(_ preset: WorkoutPreset) async throws -> URL {
        guard let fetchedPreset = try await presetRepository.fetchPreset(by: preset.persistentModelID) else {
            throw WorkoutRepositoryError.modelNotFound
        }
        return try WorkoutExportService.exportPresetToCSV(fetchedPreset.toDTO())
    }

    func importPreset(from url: URL) async -> Bool {
            do {

                let presetDTO = try WorkoutExportService.importPreset(from: url)

                try await presetRepository.createPreset(
                    name: presetDTO.name + " (Imported)",
                    icon: presetDTO.icon,
                    folderName: presetDTO.folderName, 
                    exercises: presetDTO.exercises
                )

                if let newFolder = presetDTO.folderName {
                    await MainActor.run {
                        let currentFolders = UserDefaults.standard.string(forKey: "customPresetFolders") ?? ""
                        var foldersArray = currentFolders.isEmpty ? [] : currentFolders.components(separatedBy: "|")

                        if !foldersArray.contains(newFolder) {
                            foldersArray.insert(newFolder, at: 0)
                            UserDefaults.standard.set(foldersArray.joined(separator: "|"), forKey: "customPresetFolders")
                        }
                    }
                }

                return true
            } catch {
                appState.showError(title: String(localized: "Import Failed"), message: error.localizedDescription)
                return false
            }
        }
}
extension PresetService {

    static let savedRoutinesFolderName = "Saved Routines"

    func isProgramSaved(title: String, isSingleRoutine: Bool) async -> Bool {
        do {
            let targetFolder = isSingleRoutine ? Self.savedRoutinesFolderName : title

            let descriptor = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.folderName == targetFolder })
            let existingPresets = try await presetRepository.fetchPresets(matching: descriptor)

            if isSingleRoutine {

                return existingPresets.contains { $0.name == title }
            } else {

                return !existingPresets.isEmpty
            }
        } catch {
            print("Error checking saved status: \(error)")
            return false
        }
    }

    func deleteFolder(named folderName: String) async {
        guard !folderName.isEmpty else { return } 

        do {
            let descriptor = FetchDescriptor<WorkoutPreset>(predicate: #Predicate { $0.folderName == folderName })
            let presetsToDelete = try await presetRepository.fetchPresets(matching: descriptor)

            for preset in presetsToDelete {
                try await presetRepository.deletePreset(presetID: preset.persistentModelID)
            }

            await MainActor.run {
                let currentFolders = UserDefaults.standard.string(forKey: "customPresetFolders") ?? ""
                var foldersArray = currentFolders.isEmpty ? [] : currentFolders.components(separatedBy: "|")

                if let index = foldersArray.firstIndex(of: folderName) {
                    foldersArray.remove(at: index)
                    UserDefaults.standard.set(foldersArray.joined(separator: "|"), forKey: "customPresetFolders")
                }
            }

        } catch {
            appState.showError(title: "Delete Failed", message: "Could not remove the program: \(error.localizedDescription)")
        }
    }

}
