//
//  CatalogViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 05.04.26.
//

internal import SwiftUI
import Observation

@Observable
@MainActor
final class CatalogViewModel {
    
    var customExercises: [CustomExerciseDefinition] = []
    var deletedDefaultExercises: Set<String> = []
    
    // ✅ ДОБАВЛЕНО: Стейт для загруженного из JSON каталога
    var baseCatalog: [String: [String]] = [:]
    
    private let exerciseCatalogService: ExerciseCatalogService
    
    init(exerciseCatalogService: ExerciseCatalogService) {
        self.exerciseCatalogService = exerciseCatalogService
    }
    
    var combinedCatalog: [String: [String]] {
        // ✅ ИСПОЛЬЗУЕМ ЗАГРУЖЕННЫЙ БАЗОВЫЙ КАТАЛОГ ВМЕСТО ХАРДКОДА
        var catalog = baseCatalog
        
        // Удаляем скрытые дефолтные упражнения
        for (category, exercises) in catalog {
            catalog[category] = exercises.filter { !deletedDefaultExercises.contains($0) }
        }
        
        // Добавляем кастомные
        for custom in customExercises {
            var list = catalog[custom.category] ?? []
            if !list.contains(custom.name) { list.append(custom.name) }
            catalog[custom.category] = list
        }
        return catalog
    }
    
    func loadDictionary() async {
        do {
            // ✅ Получаем базовый каталог из нового актора
            self.baseCatalog = await ExerciseDatabaseService.shared.getCatalog()
            
            let custom = try await exerciseCatalogService.fetchCustomExercises()
            let deleted = try await exerciseCatalogService.fetchDeletedDefaultExercises()
            
            self.customExercises = custom
            self.deletedDefaultExercises = deleted
        } catch {
            print("Failed to load catalog dictionary: \(error.localizedDescription)")
        }
    }
    
    func isCustomExercise(name: String) -> Bool {
        customExercises.contains { $0.name == name }
    }
    
    func addCustomExercise(name: String, category: String, muscles: [String], type: ExerciseType = .strength) async {
        do {
            try await exerciseCatalogService.addCustomExercise(name: name, category: category, muscles: muscles, type: type)
            // Синхронно обновляем маппинг в памяти
            MuscleMapping.updateCustomMapping(name: name, muscles: muscles)
            await loadDictionary()
        } catch {
            print("Failed to add custom exercise: \(error.localizedDescription)")
        }
    }
    
    func deleteCustomExercise(name: String, category: String) async {
            do {
                try await exerciseCatalogService.deleteCustomExercise(name: name, category: category)
            
                
                await loadDictionary()
            } catch {
                print("Failed to delete custom exercise: \(error.localizedDescription)")
            }
        }
    
    func deleteExercise(name: String, category: String) async {
        if isCustomExercise(name: name) {
            await deleteCustomExercise(name: name, category: category)
        } else {
            do {
                try await exerciseCatalogService.hideDefaultExercise(name: name, category: category)
                await loadDictionary()
            } catch {
                print("Failed to hide default exercise: \(error.localizedDescription)")
            }
        }
    }
}
