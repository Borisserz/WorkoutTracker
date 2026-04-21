

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class WorkoutListViewModel {
    var calculatedAvgDuration: Int = 0
    var calculatedAvgVolume: Int = 0

    func calculateStatsAsync(workouts: [Workout]) {
        let totalWorkouts = workouts.count
        guard totalWorkouts > 0 else {
            self.calculatedAvgDuration = 0
            self.calculatedAvgVolume = 0
            return
        }

        struct WorkoutStatsDTO: Sendable {
            let duration: Int
            let volume: Double
        }

        let statsData = workouts.map { workout in
            WorkoutStatsDTO(
                duration: workout.durationSeconds,
                volume: workout.totalStrengthVolume
            )
        }

        Task.detached(priority: .userInitiated) {
            var totalDurSeconds = 0
            var totalVol = 0.0

            for data in statsData {
                totalDurSeconds += data.duration 
                totalVol += data.volume
            }

            let avgDurMinutes = (totalDurSeconds / totalWorkouts) / 60
            let avgVol = Int(totalVol / Double(totalWorkouts))

            await MainActor.run {
                self.calculatedAvgDuration = avgDurMinutes
                self.calculatedAvgVolume = avgVol
            }
        }
    }
}
