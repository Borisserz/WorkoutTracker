import Foundation

public struct MuscleCategoryMapper: Sendable {

    private static let categoryToMuscles: [String: Set<String>] = [
        "chest": ["chest", "pectorals"],
        "back": ["lats", "middle back", "lower back", "traps", "trapezius", "rhomboids", "upper back", "upper-back"],
        "legs": ["quadriceps", "hamstrings", "calves", "glutes", "gluteal", "adductors", "abductors", "quads", "calf"],
        "shoulders": ["shoulders", "deltoids", "delts"],
        "arms": ["biceps", "triceps", "forearm", "forearms", "brachialis"],
        "core": ["abdominals", "abs", "obliques", "core"]
    ]

    public static func expandMuscles(from uiCategories: Set<String>) -> Set<String> {
        var expandedMuscles = Set<String>()

        for category in uiCategories {
            let normalizedCategory = category.lowercased()

            if let specificMuscles = categoryToMuscles[normalizedCategory] {
                expandedMuscles.formUnion(specificMuscles)
            }

            expandedMuscles.insert(normalizedCategory)
        }

        return expandedMuscles
    }

    public static func getBroadCategory(for rawMuscle: String) -> String {
           let lower = rawMuscle.lowercased()

           for (category, muscles) in categoryToMuscles {
               if muscles.contains(lower) || category == lower {
                   return category.capitalized
               }
           }
           return "Other"
       }
}
