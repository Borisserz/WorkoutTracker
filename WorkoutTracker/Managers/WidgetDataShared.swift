import Foundation

// Структура данных для виджета
struct WidgetData: Codable {
    let streak: Int
    let weeklyTarget: Int
    let weeklyStats: [WeeklyPoint]
    
    struct WeeklyPoint: Codable, Identifiable {
        var id: String { label }
        let label: String // "7/13"
        let count: Int
    }
}

class WidgetDataManager {
    // ВАЖНО: Убедись, что ID совпадает с тем, что ты создал в App Groups
    static let suiteName = "group.com.borisdev.WorkoutTracker"
    static let key = "widget_data"
    
    static func save(streak: Int, weeklyStats: [WidgetData.WeeklyPoint]) {
        
        let data = WidgetData(
            streak: streak,
            weeklyTarget: 3,
            weeklyStats: weeklyStats
        )
        
        if let defaults = UserDefaults(suiteName: suiteName),
           let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: key)
            // Виджет обновится сам по своему таймлайну
        }
    }
    
    static func load() -> WidgetData {
        if let defaults = UserDefaults(suiteName: suiteName),
           let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) {
            return decoded
        }
        return WidgetData(streak: 0, weeklyTarget: 3, weeklyStats: [])
    }
}
