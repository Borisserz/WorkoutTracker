//
//  AchievementModels.swift
//  WorkoutTracker
//

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
        case .none: return "Locked"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .diamond: return "Diamond"
        }
    }
}

struct Achievement: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let icon: String // Имя SF Symbol
    
    // Статус
    var tier: AchievementTier = .none
    var progress: String = "" // Изменено с LocalizedStringKey на String
    
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
        streak: Int,
        weekendWorkouts: Int = 0,
        lunchWorkouts: Int = 0
    ) -> [Achievement] {
        var list: [Achievement] = []
        let unitsManager = UnitsManager.shared
        
        // Локализованные строки для подстановок прогресса
        let maxLevelStr = String(localized: "Max Level!")
        let workoutsStr = String(localized: "workouts")
        let daysStr = String(localized: "days")
        let timesStr = String(localized: "times")
        
        // --- 1. Consistency (Количество тренировок) ---
        let wCount = Double(totalWorkouts)
        let wTierData = getTierAndTarget(current: wCount, thresholds: [1, 10, 50, 100])
        list.append(Achievement(
            title: "Consistency",
            description: "Complete workouts to level up.",
            icon: "calendar.circle.fill",
            tier: wTierData.0,
            progress: wTierData.0 == .diamond ? maxLevelStr : "\(Int(wCount)) / \(Int(wTierData.1)) \(workoutsStr)"
        ))
        
        // --- 2. Veteran (Продолжительная приверженность) ---
        let veteranTierData = getTierAndTarget(current: wCount, thresholds: [150, 365, 500, 1000])
        list.append(Achievement(
            title: "Veteran",
            description: "Reach legendary workout counts.",
            icon: "shield.fill",
            tier: veteranTierData.0,
            progress: veteranTierData.0 == .diamond ? maxLevelStr : "\(Int(wCount)) / \(Int(veteranTierData.1)) \(workoutsStr)"
        ))
        
        // --- 3. Streaks (Дней подряд) ---
        let sCount = Double(streak)
        let sTierData = getTierAndTarget(current: sCount, thresholds: [3, 7, 14, 30])
        list.append(Achievement(
            title: "On Fire",
            description: "Maintain a daily workout streak.",
            icon: "flame.fill",
            tier: sTierData.0,
            progress: sTierData.0 == .diamond ? maxLevelStr : "\(Int(sCount)) / \(Int(sTierData.1)) \(daysStr)"
        ))
        
        // --- 4. Unstoppable (Экстремальный стрик) ---
        let unstoppableTierData = getTierAndTarget(current: sCount, thresholds: [50, 100, 180, 365])
        list.append(Achievement(
            title: "Unstoppable",
            description: "Maintain a massive streak.",
            icon: "bolt.heart.fill",
            tier: unstoppableTierData.0,
            progress: unstoppableTierData.0 == .diamond ? maxLevelStr : "\(Int(sCount)) / \(Int(unstoppableTierData.1)) \(daysStr)"
        ))
        
        // --- 5. Volume (Суммарный вес) ---
        let vTierData = getTierAndTarget(current: totalVolume, thresholds: [1000, 10_000, 50_000, 100_000])
        
        let currentVolConverted = unitsManager.convertFromKilograms(totalVolume)
        let targetVolConverted = unitsManager.convertFromKilograms(vTierData.1)
        let weightUnit = unitsManager.weightUnitString()
        
        list.append(Achievement(
            title: "Heavy Lifter",
            description: "Lift a massive amount of total weight.",
            icon: "scalemass.fill",
            tier: vTierData.0,
            progress: vTierData.0 == .diamond ? maxLevelStr : "\(Int(currentVolConverted)) / \(Int(targetVolConverted)) \(weightUnit)"
        ))
        
        // --- 6. Titan (Экстремальный объем) ---
        let titanTierData = getTierAndTarget(current: totalVolume, thresholds: [250_000, 500_000, 1_000_000, 5_000_000])
        let targetTitanConverted = unitsManager.convertFromKilograms(titanTierData.1)
        list.append(Achievement(
            title: "Titan",
            description: "Lift monumental total weight.",
            icon: "mountain.2.fill",
            tier: titanTierData.0,
            progress: titanTierData.0 == .diamond ? maxLevelStr : "\(Int(currentVolConverted)) / \(Int(targetTitanConverted)) \(weightUnit)"
        ))
        
        // --- 7. Cardio (Марафонец) ---
        let distanceKm = totalDistance / 1000.0 // Переводим метры в километры для сверки с порогами
        let dTierData = getTierAndTarget(current: distanceKm, thresholds: [10, 42, 100, 500])
        
        let currentDistConverted = unitsManager.convertFromMeters(totalDistance)
        let targetDistConverted = unitsManager.convertFromMeters(dTierData.1 * 1000.0) // Цель переводим обратно в метры для отображения
        let distUnit = unitsManager.distanceUnitString()
        
        list.append(Achievement(
            title: "Marathoner",
            description: "Accumulate total cardio distance.",
            icon: "figure.run.circle.fill",
            tier: dTierData.0,
            progress: dTierData.0 == .diamond ? maxLevelStr : "\(LocalizationHelper.shared.formatDecimal(currentDistConverted)) / \(Int(targetDistConverted)) \(distUnit)"
        ))
        
        // --- 8. Globetrotter (Глобальный бегун) ---
        let globetrotterTierData = getTierAndTarget(current: distanceKm, thresholds: [1000, 2500, 5000, 10000])
        let targetGlobeConverted = unitsManager.convertFromMeters(globetrotterTierData.1 * 1000.0)
        list.append(Achievement(
            title: "Globetrotter",
            description: "Run across countries.",
            icon: "globe.europe.africa.fill",
            tier: globetrotterTierData.0,
            progress: globetrotterTierData.0 == .diamond ? maxLevelStr : "\(LocalizationHelper.shared.formatDecimal(currentDistConverted)) / \(Int(targetGlobeConverted)) \(distUnit)"
        ))
        
        // --- 9. Early Bird (Тренировки утром) ---
        let earlyTierData = getTierAndTarget(current: Double(earlyWorkouts), thresholds: [1, 5, 20, 50])
        list.append(Achievement(
            title: "Early Bird",
            description: "Work out between 4 AM and 8 AM.",
            icon: "sunrise.fill",
            tier: earlyTierData.0,
            progress: earlyTierData.0 == .diamond ? maxLevelStr : "\(earlyWorkouts) / \(Int(earlyTierData.1)) \(timesStr)"
        ))
        
        // --- 10. Night Owl (Тренировки ночью) ---
        let nightTierData = getTierAndTarget(current: Double(nightWorkouts), thresholds: [1, 5, 20, 50])
        list.append(Achievement(
            title: "Night Owl",
            description: "Work out between 10 PM and 4 AM.",
            icon: "moon.stars.fill",
            tier: nightTierData.0,
            progress: nightTierData.0 == .diamond ? maxLevelStr : "\(nightWorkouts) / \(Int(nightTierData.1)) \(timesStr)"
        ))
        
        // --- 11. Weekend Warrior (Выходные) ---
        let weekendTierData = getTierAndTarget(current: Double(weekendWorkouts), thresholds: [1, 10, 50, 100])
        list.append(Achievement(
            title: "Weekend Warrior",
            description: "Work out on Saturdays or Sundays.",
            icon: "sun.max.fill",
            tier: weekendTierData.0,
            progress: weekendTierData.0 == .diamond ? maxLevelStr : "\(weekendWorkouts) / \(Int(weekendTierData.1)) \(timesStr)"
        ))
        
        // --- 12. Midday Hustle (Обеденный перерыв) ---
        let lunchTierData = getTierAndTarget(current: Double(lunchWorkouts), thresholds: [1, 10, 50, 100])
        list.append(Achievement(
            title: "Midday Hustle",
            description: "Work out between 11 AM and 2 PM.",
            icon: "clock.fill",
            tier: lunchTierData.0,
            progress: lunchTierData.0 == .diamond ? maxLevelStr : "\(lunchWorkouts) / \(Int(lunchTierData.1)) \(timesStr)"
        ))
        
        return list
    }
    
    // MARK: - Legacy-функция для обратной совместимости
    // Если у вас есть экран "Достижения", который тоже вызывает calculateAchievements,
    // он продолжит работать через эту функцию-мост.
    static func calculateAchievements(workouts: [Workout], streak: Int) -> [Achievement] {
        
        // ИСПРАВЛЕНИЕ ОШИБКИ ТАЙМАУТА: Заменяем сложные .reduce на простые циклы for,
        // чтобы компилятор Swift мог легко их переварить.
        var totalVolume: Double = 0.0
        var totalDistance: Double = 0.0
        
        for workout in workouts {
            for exercise in workout.exercises {
                if exercise.type == ExerciseType.strength {
                    totalVolume += exercise.exerciseVolume
                } else if exercise.type == ExerciseType.cardio {
                    var distForExercise: Double = 0.0
                    for set in exercise.setsList {
                        if set.isCompleted {
                            if let d = set.distance {
                                distForExercise += d
                            }
                        }
                    }
                    
                    if distForExercise > 0 {
                        totalDistance += distForExercise
                    } else {
                        // Используем новое сохраненное свойство
                        totalDistance += (exercise.firstSetDistance ?? 0.0)
                    }
                }
            }
        }
        
        var earlyWorkouts = 0
        var nightWorkouts = 0
        var weekendWorkouts = 0
        var lunchWorkouts = 0
        
        let calendar = Calendar.current
        
        for workout in workouts {
            let hour = calendar.component(.hour, from: workout.date)
            let weekday = calendar.component(.weekday, from: workout.date)
            
            if hour >= 4 && hour < 8 {
                earlyWorkouts += 1
            }
            if hour >= 22 || hour < 4 {
                nightWorkouts += 1
            }
            if hour >= 11 && hour <= 14 {
                lunchWorkouts += 1
            }
            if weekday == 1 || weekday == 7 { // 1 = Sunday, 7 = Saturday
                weekendWorkouts += 1
            }
        }
        
        return calculateAchievements(
            totalWorkouts: workouts.count,
            totalVolume: totalVolume,
            totalDistance: totalDistance,
            earlyWorkouts: earlyWorkouts,
            nightWorkouts: nightWorkouts,
            streak: streak,
            weekendWorkouts: weekendWorkouts,
            lunchWorkouts: lunchWorkouts
        )
    }
}
