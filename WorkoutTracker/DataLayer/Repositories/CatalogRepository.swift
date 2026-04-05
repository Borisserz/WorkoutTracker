// ============================================================
// FILE: WorkoutTracker/DataLayer/Repositories/CatalogRepository.swift
// ============================================================

import Foundation
import SwiftData

protocol CatalogRepositoryProtocol: Sendable {
    func addCustomExercise(name: String, category: String, targetedMuscles: [String], type: ExerciseType) async throws
    func deleteCustomExercise(name: String, category: String) async throws
    func hideDefaultExercise(name: String, category: String) async throws
    func fetchCustomExercises() async throws -> [CustomExerciseDefinition]
    func fetchDeletedDefaultExercises() async throws -> Set<String>
}

@ModelActor
actor CatalogRepository: CatalogRepositoryProtocol {
    
    func addCustomExercise(name: String, category: String, targetedMuscles: [String], type: ExerciseType) async throws {
        // ⚠️ UPSERT LOGIC: Prevent duplicates now that @Attribute(.unique) is gone
        let descriptor = FetchDescriptor<ExerciseDictionaryItem>(predicate: #Predicate { $0.name == name && $0.isCustom == true })
        
        if let existingItem = try? modelContext.fetch(descriptor).first {
            // Update existing
            existingItem.category = category
            existingItem.targetedMuscles = targetedMuscles
            existingItem.type = type
            existingItem.isHidden = false
        } else {
            // Insert new
            let item = ExerciseDictionaryItem(name: name, category: category, targetedMuscles: targetedMuscles, type: type, isCustom: true, isHidden: false)
            modelContext.insert(item)
        }
        try modelContext.save()
    }

    func deleteCustomExercise(name: String, category: String) async throws {
        let desc = FetchDescriptor<ExerciseDictionaryItem>(predicate: #Predicate { $0.name == name && $0.isCustom == true })
        if let items = try? modelContext.fetch(desc), let item = items.first {
            item.isHidden = true
            try modelContext.save()
        }
    }

    func hideDefaultExercise(name: String, category: String) async throws {
        // ⚠️ UPSERT LOGIC
        let desc = FetchDescriptor<ExerciseDictionaryItem>(predicate: #Predicate { $0.name == name && $0.isCustom == false })
        
        if let existingItem = try? modelContext.fetch(desc).first {
            existingItem.isHidden = true
        } else {
            let item = ExerciseDictionaryItem(name: name, category: category, targetedMuscles: [], type: .strength, isCustom: false, isHidden: true)
            modelContext.insert(item)
        }
        try modelContext.save()
    }
    
    func fetchCustomExercises() async throws -> [CustomExerciseDefinition] {
        let items = (try? modelContext.fetch(FetchDescriptor<ExerciseDictionaryItem>())) ?? []
        return items.filter { $0.isCustom && !$0.isHidden }.map { CustomExerciseDefinition(id: UUID(), name: $0.name, category: $0.category, targetedMuscles: $0.targetedMuscles, type: $0.type) }
    }

    func fetchDeletedDefaultExercises() async throws -> Set<String> {
        let items = (try? modelContext.fetch(FetchDescriptor<ExerciseDictionaryItem>())) ?? []
        return Set(items.filter { $0.isHidden && !$0.isCustom }.map { $0.name })
    }
}
