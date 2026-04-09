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
            // 2. СТРОГАЯ ФИЛЬТРАЦИЯ ПО ЦЕЛЕВЫМ МЫШЦАМ
                        if !targetMuscles.isEmpty {
                            // Берем только ГЛАВНЫЕ мышцы (primaryMuscles)
                            let primary = (exercise.primaryMuscles ?? []).map { $0.lowercased() }
                            // Оставляем категорию, чтобы нормально работала вкладка "Cardio"
                            let category = exercise.category?.lowercased() ?? ""
                            
                            // Исключаем secondaryMuscles, чтобы жим лежа не попадал в плечи и т.д.
                            let exerciseTargets = Set(primary + [category])
                            
                            // Если главные мышцы упражнения не пересекаются с выбранной UI-вкладкой -> отбрасываем
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
