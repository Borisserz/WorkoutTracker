// ============================================================
// FILE: Shared/WidgetDataShared.swift
// ============================================================
import Foundation

// Модель данных для виджета
struct WidgetData: Codable {
    let streak: Int
    let weeklyTarget: Int
    let weeklyStats: [WeeklyPoint]
    
    // Новые поля для премиальных виджетов
    let recoveredMuscles: [String]
    let aiTip: String
    let totalVolumeTons: Double
    
    struct WeeklyPoint: Codable, Identifiable {
        var id: String { label }
        let label: String
        let count: Int
    }
    
    // Безопасная инициализация
    init(streak: Int, weeklyTarget: Int, weeklyStats: [WeeklyPoint], recoveredMuscles: [String], aiTip: String, totalVolumeTons: Double) {
        self.streak = streak
        self.weeklyTarget = weeklyTarget
        self.weeklyStats = weeklyStats
        self.recoveredMuscles = recoveredMuscles
        self.aiTip = aiTip
        self.totalVolumeTons = totalVolumeTons
    }
    
    // Безопасный декодинг для поддержки старых версий
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        weeklyTarget = try container.decodeIfPresent(Int.self, forKey: .weeklyTarget) ?? 3
        weeklyStats = try container.decodeIfPresent([WeeklyPoint].self, forKey: .weeklyStats) ?? []
        recoveredMuscles = try container.decodeIfPresent([String].self, forKey: .recoveredMuscles) ?? ["Chest", "Arms"]
        aiTip = try container.decodeIfPresent(String.self, forKey: .aiTip) ?? "Ready for your next session. Let's go!"
        totalVolumeTons = try container.decodeIfPresent(Double.self, forKey: .totalVolumeTons) ?? 0.0
    }
}

class WidgetDataManager {
    static let suiteName = "group.com.borisdev.WorkoutTracker"
    static let key = "widget_data"
    
    static func save(streak: Int, weeklyStats: [WidgetData.WeeklyPoint], recoveredMuscles: [String] = [], aiTip: String = "", totalVolumeTons: Double = 0.0) {
        let data = WidgetData(
            streak: streak,
            weeklyTarget: 3,
            weeklyStats: weeklyStats,
            recoveredMuscles: recoveredMuscles,
            aiTip: aiTip,
            totalVolumeTons: totalVolumeTons
        )
        
        if let defaults = UserDefaults(suiteName: suiteName),
           let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: key)
        }
    }
    
    static func load() -> WidgetData {
            if let defaults = UserDefaults(suiteName: suiteName),
               let data = defaults.data(forKey: key),
               let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) {
                return decoded
            }
            // Возвращаем пустые данные с призывом открыть приложение
            return WidgetData(
                streak: 0,
                weeklyTarget: 3,
                weeklyStats: [],
                recoveredMuscles: [],
                aiTip: String(localized: "Open the app and log your first workout!"),
                totalVolumeTons: 0.0
            )
        }
}
