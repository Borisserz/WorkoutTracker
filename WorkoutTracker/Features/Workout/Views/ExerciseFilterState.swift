import Foundation
internal import SwiftUI
import Observation

@Observable
final class ExerciseFilterState {
    var searchText: String = ""
    
    var selectedMuscles: Set<String> = [] // То, что пользователь тыкает в UI (например, ["legs"])
    var selectedEquipment: Set<String> = []
    var selectedMechanic: Set<String> = []
    var selectedLevel: Set<String> = []
    
    var activeAdvancedFiltersCount: Int {
        selectedEquipment.count + selectedMechanic.count + selectedLevel.count
    }
    
    func clearAdvancedFilters() {
        selectedEquipment.removeAll()
        selectedMechanic.removeAll()
        selectedLevel.removeAll()
    }
    
    func toggle(item: String, in collection: inout Set<String>) {
        if collection.contains(item) {
            collection.remove(item)
        } else {
            collection.insert(item)
        }
    }
    
    func filter(exercises: [ExerciseDBItem]) -> [ExerciseDBItem] {
        let searchQuery = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        
        // 1. РАЗВОРАЧИВАЕМ UI-КАТЕГОРИИ В СПИСОК АНАТОМИЧЕСКИХ МЫШЦ
        // Если выбрано ["legs"], получим ["quadriceps", "hamstrings", "calves", ...]
        let targetMuscles = MuscleCategoryMapper.expandMuscles(from: selectedMuscles)
        
        return exercises.filter { exercise in
            // Поиск по тексту
            if !searchQuery.isEmpty && !exercise.name.localizedCaseInsensitiveContains(searchQuery) {
                return false
            }
            
            // 2. ИСПРАВЛЕННАЯ ФИЛЬТРАЦИЯ ПО МЫШЦАМ
            if !targetMuscles.isEmpty {
                let primary = (exercise.primaryMuscles ?? []).map { $0.lowercased() }
                let secondary = (exercise.secondaryMuscles ?? []).map { $0.lowercased() }
                let category = exercise.category?.lowercased() ?? ""
                
                // Собираем все мышцы, задействованные в упражнении
                let exerciseTargets = Set(primary + secondary + [category])
                
                // Если нет пересечений (т.е. наборы Disjoint) -> отбрасываем упражнение
                if targetMuscles.isDisjoint(with: exerciseTargets) {
                    return false
                }
            }
            
            // Фильтрация по оборудованию
            if !selectedEquipment.isEmpty {
                let eq = exercise.equipment?.lowercased() ?? "bodyweight"
                if !selectedEquipment.contains(eq) { return false }
            }
            
            // Фильтрация по механике (Изоляция/База)
            if !selectedMechanic.isEmpty {
                let mech = exercise.mechanic?.lowercased() ?? "compound"
                if !selectedMechanic.contains(mech) { return false }
            }
            
            // Фильтрация по уровню
            if !selectedLevel.isEmpty {
                let lvl = exercise.level?.lowercased() ?? "intermediate"
                if !selectedLevel.contains(lvl) { return false }
            }
            
            return true // Упражнение прошло все фильтры
        }
    }
}
