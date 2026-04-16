//
//  CalorieCalculator.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 16.04.26.
//

// ============================================================
// FILE: WorkoutTracker/CoreLogic/Helpers/CalorieCalculator.swift
// ============================================================
import Foundation

struct CalorieCalculator: Sendable {
    
    /// Расчет сожженных калорий на основе реальной выполненной работы
    static func calculate(for workout: Workout, userWeight: Double) -> Int {
        let safeWeight = userWeight > 10 ? userWeight : 75.0
        
        var totalStrengthActiveSeconds = 0
        var totalCardioActiveSeconds = 0
        
        // 1. Считаем чистое активное время из выполненных подходов
        for exercise in workout.exercises {
            let targets = exercise.isSuperset ? exercise.subExercises : [exercise]
            
            for ex in targets {
                let completedSets = ex.setsList.filter { $0.isCompleted }
                guard !completedSets.isEmpty else { continue }
                
                switch ex.type {
                case .strength:
                    // В среднем 1 силовой подход занимает 40 секунд времени под нагрузкой
                    totalStrengthActiveSeconds += completedSets.count * 40
                case .duration, .cardio:
                    // Для кардио и планок берем реальное залогированное время
                    let timeInSeconds = completedSets.compactMap { $0.time }.reduce(0, +)
                    totalCardioActiveSeconds += timeInSeconds > 0 ? timeInSeconds : (completedSets.count * 60)
                }
            }
        }
        
        // 2. Распределяем общее время тренировки
        let totalWorkoutSeconds = workout.durationSeconds > 0 ? workout.durationSeconds : 3600 // Защита от 0
        
        // Активное время не может превышать общее время тренировки
        let actualStrengthActive = min(totalStrengthActiveSeconds, totalWorkoutSeconds)
        let actualCardioActive = min(totalCardioActiveSeconds, totalWorkoutSeconds - actualStrengthActive)
        
        // Всё остальное время — это отдых между подходами, ходьба до кулера и т.д.
        let restingSeconds = max(0, totalWorkoutSeconds - actualStrengthActive - actualCardioActive)
        
        // 3. Применяем разные MET-коэффициенты
        // Силовая работа: 6.0 MET
        // Кардио (среднее): 8.0 MET
        // Отдых (стоя/ходя по залу): 2.0 MET
        
        let strengthCals = (Double(actualStrengthActive) / 3600.0) * 6.0 * safeWeight
        let cardioCals = (Double(actualCardioActive) / 3600.0) * 8.0 * safeWeight
        let restingCals = (Double(restingSeconds) / 3600.0) * 2.0 * safeWeight
        
        let totalCals = strengthCals + cardioCals + restingCals
        
        // Защита: минимум 10 ккал, чтобы не было нулей
        return max(10, Int(totalCals))
    }
}
