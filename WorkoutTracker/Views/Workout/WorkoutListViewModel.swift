//
//  WorkoutListViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 2.04.26.
//

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
        
        // Извлекаем нужные данные в DTO, чтобы безопасно передать в фоновый поток (без утечек SwiftData Models)
        struct WorkoutStatsDTO: Sendable {
            let duration: Int
            let volume: Double
        }
        
        let statsData = workouts.map { workout in
            WorkoutStatsDTO(
                duration: workout.durationSeconds,
                volume: workout.exercises.reduce(0.0) { $0 + $1.exerciseVolume }
            )
        }
        
        // Выполняем математику в фоне
        Task.detached(priority: .userInitiated) {
            var totalDur = 0
            var totalVol = 0.0
            
            for data in statsData {
                totalDur += (data.duration / 60)
                totalVol += data.volume
            }
            
            let avgDur = totalDur / totalWorkouts
            let avgVol = Int(totalVol / Double(totalWorkouts))
            
            // Возвращаем результат в UI
            await MainActor.run {
                self.calculatedAvgDuration = avgDur
                self.calculatedAvgVolume = avgVol
            }
        }
    }
}
