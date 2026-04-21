import Foundation
internal import SwiftUI
import Observation

@Observable
final class ExerciseFilterState {
    var searchText: String = ""

    var selectedMuscles: Set<String> = [] 
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
        let targetMuscles = MuscleCategoryMapper.expandMuscles(from: selectedMuscles)

        return exercises.filter { exercise in

            if !searchQuery.isEmpty {
                       let localizedName = LocalizationHelper.shared.translateName(exercise.name).lowercased()
                       if !exercise.name.localizedCaseInsensitiveContains(searchQuery) &&
                          !localizedName.contains(searchQuery) {
                           return false
                       }
                   }

                        if !targetMuscles.isEmpty {

                            let primary = (exercise.primaryMuscles ?? []).map { $0.lowercased() }

                            let category = exercise.category?.lowercased() ?? ""

                            let exerciseTargets = Set(primary + [category])

                            if targetMuscles.isDisjoint(with: exerciseTargets) {
                                return false
                            }
                        }

            if !selectedEquipment.isEmpty {
                let eq = exercise.equipment?.lowercased() ?? "bodyweight"
                if !selectedEquipment.contains(eq) { return false }
            }

            if !selectedMechanic.isEmpty {
                let mech = exercise.mechanic?.lowercased() ?? "compound"
                if !selectedMechanic.contains(mech) { return false }
            }

            if !selectedLevel.isEmpty {
                let lvl = exercise.level?.lowercased() ?? "intermediate"
                if !selectedLevel.contains(lvl) { return false }
            }

            return true 
        }
    }
}
