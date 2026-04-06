//
//  PresetService.swift
//  WorkoutTracker
//

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
    
    // MARK: - Presets Operations
    
    // MARK: - Presets Operations
        
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
    
    // MARK: - Import/Export
    
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
                // 1. Получаем готовый DTO из файла
                let presetDTO = try WorkoutExportService.importPreset(from: url)
                
                // 2. Передаем DTO в репозиторий вместе с папкой
                try await presetRepository.createPreset(
                    name: presetDTO.name + " (Imported)",
                    icon: presetDTO.icon,
                    folderName: presetDTO.folderName, // ✅ ИСПРАВЛЕНИЕ: Добавлен недостающий параметр
                    exercises: presetDTO.exercises
                )
                
                // 3. Если пришел с папкой, которую мы еще не знаем, добавляем в UI (AppStorage)
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
