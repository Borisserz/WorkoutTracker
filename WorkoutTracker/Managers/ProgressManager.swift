//
//  ProgressManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 24.12.25.
//

import Combine
import Foundation
internal import SwiftUI

class ProgressManager: ObservableObject {
    
    // --- ОСНОВНЫЕ ДАННЫЕ ---
    @Published private(set) var level: Int = 1
    @Published private(set) var totalXP: Int = 0
    
    private let levelKey = "userLevel"
    private let xpKey = "userTotalXP"
    
    // Константы для баланса
    private let baseXP = 1000.0
    private let multiplier = 1.2
    
    init() {
        loadProgress()
        recalculateLevelFromXP()
    }
    
    // --- МАТЕМАТИКА УРОВНЕЙ ---
    
    private func cumulativeXPRequired(forLevel n: Int) -> Int {
        if n <= 1 { return 0 }
        let power = pow(multiplier, Double(n - 1))
        let total = baseXP * (power - 1) / (multiplier - 1)
        return Int(total)
    }
    
    // --- ПЕРЕМЕННЫЕ ДЛЯ UI ---
    
    var xpToNextLevel: Int {
        return cumulativeXPRequired(forLevel: level + 1)
    }
    
    var currentXPInLevel: Int {
        let startOfLevelXP = cumulativeXPRequired(forLevel: level)
        let val = totalXP - startOfLevelXP
        return max(val, 0)
    }
    
    var progressPercentage: Double {
        let startOfLevelXP = cumulativeXPRequired(forLevel: level)
        let nextLevelXP = cumulativeXPRequired(forLevel: level + 1)
        
        let xpNeededForThisLevel = Double(nextLevelXP - startOfLevelXP)
        let xpGainedInThisLevel = Double(totalXP - startOfLevelXP)
        
        if xpNeededForThisLevel <= 0 { return 0 }
        
        let progress = xpGainedInThisLevel / xpNeededForThisLevel
        return min(max(progress, 0.0), 1.0)
    }

    // --- ЛОГИКА ---
    
    func addXP(for workout: Workout) {
        let xpGained = calculateXP(for: workout)
        totalXP += xpGained
        print("Gained \(xpGained) XP! Total XP is now \(totalXP).")
        
        checkForLevelUp()
        saveProgress()
    }
    
    private func calculateXP(for workout: Workout) -> Int {
        // ИСПРАВЛЕНИЕ: Используем computedVolume, чтобы учитывать Супер-сеты
        let totalVolume = workout.exercises.reduce(0.0) { partialResult, exercise in
            return partialResult + exercise.computedVolume
        }
        
        // Формула XP: Объем / 5 * Коэффициент усталости
        let effortMultiplier = 1.0 + (Double(workout.effortPercentage) / 100.0)
        let baseXp = totalVolume / 5.0
        
        return Int(baseXp * effortMultiplier)
    }
    
    private func checkForLevelUp() {
        while totalXP >= cumulativeXPRequired(forLevel: level + 1) {
            level += 1
            print("LEVEL UP! Now level \(level)")
        }
        saveProgress()
    }
    
    private func recalculateLevelFromXP() {
        var calculatedLevel = 1
        while totalXP >= cumulativeXPRequired(forLevel: calculatedLevel + 1) {
            calculatedLevel += 1
        }
        
        if level != calculatedLevel {
            print("Correction: Level adjusted from \(level) to \(calculatedLevel) based on XP")
            level = calculatedLevel
            saveProgress()
        }
    }
    
    // --- СОХРАНЕНИЕ ---
    
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
