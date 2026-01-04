//
//  ProgressManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//
//  Менеджер геймификации.
//  Отвечает за:
//  1. Подсчет опыта (XP) на основе объема тренировки и усилий.
//  2. Расчет уровней (Level Up) по геометрической прогрессии.
//  3. Сохранение прогресса игрока.
//

import Combine
import Foundation
internal import SwiftUI

class ProgressManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var level: Int = 1
    @Published private(set) var totalXP: Int = 0
    
    // MARK: - Constants & Keys
    
    private let levelKey = "userLevel"
    private let xpKey = "userTotalXP"
    
    // Баланс уровней
    private let baseXP = 1000.0    // Опыт для первого уровня
    private let multiplier = 1.2   // Коэффициент сложности следующего уровня
    
    // MARK: - Init
    
    init() {
        loadProgress()
        recalculateLevelFromXP()
    }
    
    // MARK: - Level Math
    
    /// Вычисляет суммарный XP, необходимый для достижения уровня `n`.
    /// Используется формула суммы геометрической прогрессии.
    private func cumulativeXPRequired(forLevel n: Int) -> Int {
        if n <= 1 { return 0 }
        let power = pow(multiplier, Double(n - 1))
        let total = baseXP * (power - 1) / (multiplier - 1)
        return Int(total)
    }
    
    // MARK: - UI Helpers
    
    /// Общее количество XP, нужное для достижения СЛЕДУЮЩЕГО уровня (абсолютное число)
    var xpToNextLevel: Int {
        return cumulativeXPRequired(forLevel: level + 1)
    }
    
    /// Текущий прогресс внутри уровня (например, набрал 500 из 1000 нужных для апа)
    var currentXPInLevel: Int {
        let startOfLevelXP = cumulativeXPRequired(forLevel: level)
        let val = totalXP - startOfLevelXP
        return max(val, 0)
    }
    
    /// Процент прогресса для ProgressView (от 0.0 до 1.0)
    var progressPercentage: Double {
        let startOfLevelXP = cumulativeXPRequired(forLevel: level)
        let nextLevelXP = cumulativeXPRequired(forLevel: level + 1)
        
        let xpNeededForThisLevel = Double(nextLevelXP - startOfLevelXP)
        let xpGainedInThisLevel = Double(totalXP - startOfLevelXP)
        
        if xpNeededForThisLevel <= 0 { return 0 }
        
        let progress = xpGainedInThisLevel / xpNeededForThisLevel
        return min(max(progress, 0.0), 1.0)
    }

    // MARK: - Logic
    
    /// Начисляет опыт за завершенную тренировку и проверяет повышение уровня
    func addXP(for workout: Workout) {
        let xpGained = calculateXP(for: workout)
        totalXP += xpGained
        print("🎉 Gained \(xpGained) XP! Total XP is now \(totalXP).")
        
        checkForLevelUp()
        saveProgress()
    }
    
    /// Формула расчета XP: Объем / 5 * Коэффициент усталости (RPE)
    private func calculateXP(for workout: Workout) -> Int {
        // Учитываем объем всех упражнений (включая вложенные в супер-сеты)
        let totalVolume = workout.exercises.reduce(0.0) { partialResult, exercise in
            return partialResult + exercise.computedVolume
        }
        
        let effortMultiplier = 1.0 + (Double(workout.effortPercentage) / 100.0)
        let baseXp = totalVolume / 5.0
        
        return Int(baseXp * effortMultiplier)
    }
    
    private func checkForLevelUp() {
        // Проверяем, хватает ли XP на следующий уровень (может апнуться сразу несколько)
        while totalXP >= cumulativeXPRequired(forLevel: level + 1) {
            level += 1
            print("🆙 LEVEL UP! Now level \(level)")
        }
        saveProgress()
    }
    
    /// Синхронизирует уровень с текущим XP (на случай ошибок или ручного редактирования)
    private func recalculateLevelFromXP() {
        var calculatedLevel = 1
        while totalXP >= cumulativeXPRequired(forLevel: calculatedLevel + 1) {
            calculatedLevel += 1
        }
        
        if level != calculatedLevel {
            print("⚠️ Correction: Level adjusted from \(level) to \(calculatedLevel) based on XP")
            level = calculatedLevel
            saveProgress()
        }
    }
    
    // MARK: - Persistence
    
    private func saveProgress() {
        UserDefaults.standard.set(level, forKey: levelKey)
        UserDefaults.standard.set(totalXP, forKey: xpKey)
    }
    
    private func loadProgress() {
        level = UserDefaults.standard.integer(forKey: levelKey)
        totalXP = UserDefaults.standard.integer(forKey: xpKey)
        if level == 0 { level = 1 }
    }
}
