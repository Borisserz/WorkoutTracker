import Foundation
internal import SwiftUI

// Уровни достижений
enum AchievementTier: Int, Comparable {
    case none = 0
    case bronze = 1
    case silver = 2
    case gold = 3
    case diamond = 4
    
    static func < (lhs: AchievementTier, rhs: AchievementTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var name: LocalizedStringKey {
        switch self {
        case .none: return LocalizedStringKey("Locked")
        case .bronze: return LocalizedStringKey("Bronze")
        case .silver: return LocalizedStringKey("Silver")
        case .gold: return LocalizedStringKey("Gold")
        case .diamond: return LocalizedStringKey("Diamond")
        }
    }
}

struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String // Имя SF Symbol
    
    // Статус
    var tier: AchievementTier = .none
    var progress: String = "" // "5/10"
    
    var isUnlocked: Bool { tier != .none }
}

class AchievementCalculator {
    
    // Вспомогательная функция для определения уровня и следующей цели
    private static func getTierAndTarget(current: Double, thresholds: [Double]) -> (AchievementTier, Double) {
        if current >= thresholds[3] { return (.diamond, thresholds[3]) } // Максимальный уровень
        if current >= thresholds[2] { return (.gold, thresholds[3]) }
        if current >= thresholds[1] { return (.silver, thresholds[2]) }
        if current >= thresholds[0] { return (.bronze, thresholds[1]) }
        return (.none, thresholds[0])
    }
    
    static func calculateAchievements(workouts: [Workout], streak: Int) -> [Achievement] {
        var list: [Achievement] = []
        
        // --- 1. Consistency (Количество тренировок) ---
        let wCount = Double(workouts.count)
        let wTierData = getTierAndTarget(current: wCount, thresholds: [1, 10, 50, 100])
        list.append(Achievement(
            title: "Consistency",
            description: "Complete workouts to level up.",
            icon: "calendar.circle.fill",
            tier: wTierData.0,
            progress: wTierData.0 == .diamond ? "Max Level!" : "\(Int(wCount)) / \(Int(wTierData.1)) workouts"
        ))
        
        // --- 2. Streaks (Дней подряд) ---
        let sCount = Double(streak)
        let sTierData = getTierAndTarget(current: sCount, thresholds: [3, 7, 14, 30])
        list.append(Achievement(
            title: "On Fire",
            description: "Maintain a daily workout streak.",
            icon: "flame.fill",
            tier: sTierData.0,
            progress: sTierData.0 == .diamond ? "Max Level!" : "\(Int(sCount)) / \(Int(sTierData.1)) days"
        ))
        
        // --- 3. Volume (Суммарный вес) ---
        let totalVolume = workouts.reduce(0.0) { wSum, w in
            wSum + w.exercises.reduce(0.0) { eSum, e in
                e.type == .strength ? eSum + e.computedVolume : eSum
            }
        }
        let vTierData = getTierAndTarget(current: totalVolume, thresholds: [1000, 10_000, 50_000, 100_000])
        list.append(Achievement(
            title: "Heavy Lifter",
            description: "Lift a massive amount of total weight.",
            icon: "scalemass.fill",
            tier: vTierData.0,
            progress: vTierData.0 == .diamond ? "Max Level!" : "\(Int(totalVolume)) / \(Int(vTierData.1)) kg"
        ))
        
        // --- 4. Cardio (Марафонец) ---
        let totalDistance = workouts.reduce(0.0) { wSum, w in
            wSum + w.exercises.reduce(0.0) { eSum, e in
                e.type == .cardio ? eSum + (e.distance ?? 0) : eSum
            }
        }
        let dTierData = getTierAndTarget(current: totalDistance, thresholds: [10, 42, 100, 500])
        list.append(Achievement(
            title: "Marathoner",
            description: "Accumulate total cardio distance.",
            icon: "figure.run.circle.fill",
            tier: dTierData.0,
            progress: dTierData.0 == .diamond ? "Max Level!" : "\(LocalizationHelper.shared.formatDecimal(totalDistance)) / \(Int(dTierData.1)) km"
        ))
        
        // --- 5. Early Bird (Тренировки утром) ---
        let earlyWorkouts = workouts.filter {
            let hour = Calendar.current.component(.hour, from: $0.date)
            return hour >= 4 && hour < 8
        }.count
        let earlyTierData = getTierAndTarget(current: Double(earlyWorkouts), thresholds: [1, 5, 20, 50])
        list.append(Achievement(
            title: "Early Bird",
            description: "Work out between 4 AM and 8 AM.",
            icon: "sunrise.fill",
            tier: earlyTierData.0,
            progress: earlyTierData.0 == .diamond ? "Max Level!" : "\(earlyWorkouts) / \(Int(earlyTierData.1)) times"
        ))
        
        // --- 6. Night Owl (Тренировки ночью) ---
        let nightWorkouts = workouts.filter {
            let hour = Calendar.current.component(.hour, from: $0.date)
            return hour >= 22 || hour < 4
        }.count
        let nightTierData = getTierAndTarget(current: Double(nightWorkouts), thresholds: [1, 5, 20, 50])
        list.append(Achievement(
            title: "Night Owl",
            description: "Work out between 10 PM and 4 AM.",
            icon: "moon.stars.fill",
            tier: nightTierData.0,
            progress: nightTierData.0 == .diamond ? "Max Level!" : "\(nightWorkouts) / \(Int(nightTierData.1)) times"
        ))
        
        return list
    }
}

