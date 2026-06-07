

import Foundation
internal import SwiftUI
import Observation



@Observable
class ProgressManager {

    private(set) var level: Int = 1
    private(set) var totalXP: Int = 0

    private let levelKey = "userLevel"
    private let xpKey = "userTotalXP"

    private let baseXP = 1000.0
    private let multiplier = 1.2

    init() {
        loadProgress()
        recalculateLevelFromXP()
    }

    var currentTitle: String {
        switch level {
        case 1...4: return "Rookie"
        case 5...9: return "Iron Trainee"
        case 10...19: return "Gym Regular"
        case 20...29: return "Dedicated Athlete"
        case 30...49: return "Iron Master"
        default: return "Titan"
        }
    }

    private func cumulativeXPRequired(forLevel n: Int) -> Int {
        if n <= 1 { return 0 }
        let power = pow(multiplier, Double(n - 1))
        let total = baseXP * (power - 1) / (multiplier - 1)
        return Int(total)
    }

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

    func addXP(for workout: Workout, prCount: Int = 0) -> XPBreakdown {
        let breakdown = calculateXP(for: workout, prCount: prCount)
        totalXP += breakdown.total

        checkForLevelUp()
        saveProgress()
        
        return breakdown
    }

    private func calculateXP(for workout: Workout, prCount: Int) -> XPBreakdown {
        let baseCompletionXP = 150
        
        // Calculate duration XP (5 XP per minute)
        let durationMinutes = workout.durationSeconds / 60
        let durationXP = Int(durationMinutes * 5)
        
        // Calculate sets XP (10 XP per set)
        let totalSets = workout.exercises.reduce(0) { $0 + $1.setsList.count }
        let setsXP = totalSets * 10
        
        // Calculate PR XP (50 XP per PR)
        let prXP = prCount * 50
        
        // Retain some volume XP so heavy lifters get rewarded, but scaled down
        let totalVolume = workout.exercises.reduce(0.0) { partialResult, exercise in
            return partialResult + exercise.exerciseVolume
        }
        let volumeXP = Int(totalVolume / 20.0) // Scale down volume contribution

        let effortMultiplier = 1.0 + (Double(workout.effortPercentage) / 100.0)

        return XPBreakdown(
            baseXP: baseCompletionXP,
            durationXP: durationXP,
            setsXP: setsXP,
            prXP: prXP,
            volumeXP: volumeXP,
            effortMultiplier: effortMultiplier
        )
    }

    private func checkForLevelUp() {

        while totalXP >= cumulativeXPRequired(forLevel: level + 1) {
            level += 1
        }
        saveProgress()
    }

    private func recalculateLevelFromXP() {
        var calculatedLevel = 1
        while totalXP >= cumulativeXPRequired(forLevel: calculatedLevel + 1) {
            calculatedLevel += 1
        }

        if level != calculatedLevel {
            level = calculatedLevel
            saveProgress()
        }
    }

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
