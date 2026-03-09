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
    
    // MARK: - ОПТИМИЗИРОВАННАЯ ФУНКЦИЯ (O(1))
    // Не вызывает N+1 проблему, работает с готовыми агрегированными данными.
    static func calculateAchievements(
        totalWorkouts: Int,
        totalVolume: Double,
        totalDistance: Double,
        earlyWorkouts: Int,
        nightWorkouts: Int,
        streak: Int
    ) -> [Achievement] {
        var list: [Achievement] = []
        let unitsManager = UnitsManager.shared
        
        // --- 1. Consistency (Количество тренировок) ---
        let wCount = Double(totalWorkouts)
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
        let vTierData = getTierAndTarget(current: totalVolume, thresholds: [1000, 10_000, 50_000, 100_000])
        
        let currentVolConverted = unitsManager.convertFromKilograms(totalVolume)
        let targetVolConverted = unitsManager.convertFromKilograms(vTierData.1)
        let weightUnit = unitsManager.weightUnitString()
        
        list.append(Achievement(
            title: "Heavy Lifter",
            description: "Lift a massive amount of total weight.",
            icon: "scalemass.fill",
            tier: vTierData.0,
            progress: vTierData.0 == .diamond ? "Max Level!" : "\(Int(currentVolConverted)) / \(Int(targetVolConverted)) \(weightUnit)"
        ))
        
        // --- 4. Cardio (Марафонец) ---
        let dTierData = getTierAndTarget(current: totalDistance, thresholds: [10, 42, 100, 500])
        
        let currentDistConverted = unitsManager.convertFromKilometers(totalDistance)
        let targetDistConverted = unitsManager.convertFromKilometers(dTierData.1)
        let distUnit = unitsManager.distanceUnitString()
        
        list.append(Achievement(
            title: "Marathoner",
            description: "Accumulate total cardio distance.",
            icon: "figure.run.circle.fill",
            tier: dTierData.0,
            progress: dTierData.0 == .diamond ? "Max Level!" : "\(LocalizationHelper.shared.formatDecimal(currentDistConverted)) / \(Int(targetDistConverted)) \(distUnit)"
        ))
        
        // --- 5. Early Bird (Тренировки утром) ---
        let earlyTierData = getTierAndTarget(current: Double(earlyWorkouts), thresholds: [1, 5, 20, 50])
        list.append(Achievement(
            title: "Early Bird",
            description: "Work out between 4 AM and 8 AM.",
            icon: "sunrise.fill",
            tier: earlyTierData.0,
            progress: earlyTierData.0 == .diamond ? "Max Level!" : "\(earlyWorkouts) / \(Int(earlyTierData.1)) times"
        ))
        
        // --- 6. Night Owl (Тренировки ночью) ---
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
    
    // MARK: - Legacy-функция для обратной совместимости
    // Если у вас есть экран "Достижения", который тоже вызывает calculateAchievements,
    // он продолжит работать через эту функцию-мост.
    static func calculateAchievements(workouts: [Workout], streak: Int) -> [Achievement] {
        let totalVolume = workouts.reduce(0.0) { wSum, w in
            wSum + w.exercises.reduce(0.0) { eSum, e in
                e.type == .strength ? eSum + e.computedVolume : eSum
            }
        }
        
        let totalDistance = workouts.reduce(0.0) { wSum, w in
            wSum + w.exercises.reduce(0.0) { eSum, e in
                if e.type == .cardio {
                    let totalDist = e.setsList.filter { $0.isCompleted }.compactMap { $0.distance }.reduce(0.0, +)
                    return eSum + ((totalDist > 0) ? totalDist : (e.distance ?? 0.0))
                }
                return eSum
            }
        }
        
        let earlyWorkouts = workouts.filter {
            let hour = Calendar.current.component(.hour, from: $0.date)
            return hour >= 4 && hour < 8
        }.count
        
        let nightWorkouts = workouts.filter {
            let hour = Calendar.current.component(.hour, from: $0.date)
            return hour >= 22 || hour < 4
        }.count
        
        return calculateAchievements(
            totalWorkouts: workouts.count,
            totalVolume: totalVolume,
            totalDistance: totalDistance,
            earlyWorkouts: earlyWorkouts,
            nightWorkouts: nightWorkouts,
            streak: streak
        )
    }
}

