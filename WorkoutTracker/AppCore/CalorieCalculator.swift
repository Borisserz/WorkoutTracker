

import Foundation

struct CalorieCalculator: Sendable {

    static func calculate(for workout: Workout, userWeight: Double) -> Int {
        let safeWeight = userWeight > 10 ? userWeight : 75.0

        var totalStrengthActiveSeconds = 0
        var totalCardioActiveSeconds = 0

        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]

            for ex in targets {
                let completedSets = ex.setsList.filter { $0.isCompleted }
                guard !completedSets.isEmpty else { continue }

                switch ex.type {
                case .strength:

                    totalStrengthActiveSeconds += completedSets.count * 40
                case .duration, .cardio:

                    let timeInSeconds = completedSets.compactMap { $0.time }.reduce(0, +)
                    totalCardioActiveSeconds += timeInSeconds > 0 ? timeInSeconds : (completedSets.count * 60)
                }
            }
        }

        let totalWorkoutSeconds = workout.durationSeconds > 0 ? workout.durationSeconds : 3600 

        let actualStrengthActive = min(totalStrengthActiveSeconds, totalWorkoutSeconds)
        let actualCardioActive = min(totalCardioActiveSeconds, totalWorkoutSeconds - actualStrengthActive)

        let restingSeconds = max(0, totalWorkoutSeconds - actualStrengthActive - actualCardioActive)

        let strengthCals = (Double(actualStrengthActive) / 3600.0) * 6.0 * safeWeight
        let cardioCals = (Double(actualCardioActive) / 3600.0) * 8.0 * safeWeight
        let restingCals = (Double(restingSeconds) / 3600.0) * 2.0 * safeWeight

        let totalCals = strengthCals + cardioCals + restingCals

        return max(10, Int(totalCals))
    }
}
