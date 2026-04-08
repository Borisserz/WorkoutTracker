import Foundation

/// Структура для связывания широких UI-категорий с конкретными анатомическими мышцами из JSON.
/// Полностью Sendable и Thread-Safe.
public struct MuscleCategoryMapper: Sendable {
    
    // Словарь: UI-Категория -> Набор анатомических мышц
    private static let categoryToMuscles: [String: Set<String>] = [
        "chest": ["chest", "pectorals"],
        "back": ["lats", "middle back", "lower back", "traps", "trapezius", "rhomboids", "upper back", "upper-back"],
        "legs": ["quadriceps", "hamstrings", "calves", "glutes", "gluteal", "adductors", "abductors", "quads", "calf"],
        "shoulders": ["shoulders", "deltoids", "delts"],
        "arms": ["biceps", "triceps", "forearm", "forearms", "brachialis"],
        "core": ["abdominals", "abs", "obliques", "core"]
    ]
    
    /// Расширяет выбранные в UI категории до полного списка анатомических мышц.
    /// - Parameter uiCategories: Набор выбранных фильтров (например, ["legs", "core"])
    /// - Returns: Развернутый набор для быстрого поиска (O(1))
    public static func expandMuscles(from uiCategories: Set<String>) -> Set<String> {
        var expandedMuscles = Set<String>()
        
        for category in uiCategories {
            let normalizedCategory = category.lowercased()
            
            // Если для категории есть маппинг мышц, добавляем их
            if let specificMuscles = categoryToMuscles[normalizedCategory] {
                expandedMuscles.formUnion(specificMuscles)
            }
            
            // Обязательно добавляем само название категории на случай прямого совпадения (fallback)
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
