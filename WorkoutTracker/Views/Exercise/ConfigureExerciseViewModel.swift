//
//  ConfigureExerciseViewModel.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 3.04.26.
//

internal import SwiftUI
import Observation

@Observable
@MainActor
final class ConfigureExerciseViewModel {
    var form = ExerciseFormState()
    
    var showValidationAlert = false
    var hasAutoFilled = false
    var showOverloadBanner = false
    var recommendedWeight: Double = 0.0
    
    let exerciseName: String
    let muscleGroup: String
    let exerciseType: ExerciseType
    
    init(exerciseName: String, muscleGroup: String, exerciseType: ExerciseType) {
        self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup
        self.exerciseType = exerciseType
    }
    
    /// Загружает последние данные и вычисляет прогрессивную перегрузку
    func loadLastPerformance(from dashboardCache: [String: Exercise]) {
        guard !hasAutoFilled else { return }
        hasAutoFilled = true
        
        guard let lastPerf = dashboardCache[exerciseName] else { return }
        let lastSets = lastPerf.sortedSets.filter { $0.type != .warmup && $0.isCompleted }
        guard !lastSets.isEmpty else { return }
        
        switch exerciseType {
        case .strength:
            form.sets = lastSets.count
            form.reps = lastSets.first?.reps ?? 10
            
            let lastMax = lastSets.compactMap { $0.weight }.max() ?? 0.0
            form.weight = lastMax > 0 ? lastMax : nil
            
            if lastMax > 0 {
                // БИЗНЕС-ЛОГИКА НАХОДИТСЯ ЗДЕСЬ, А НЕ ВО VIEW
                self.recommendedWeight = lastMax + 2.5
                self.showOverloadBanner = true
            }
            
        case .cardio:
            if let firstSet = lastSets.first {
                form.distance = firstSet.distance
                let t = firstSet.time ?? 0
                form.minutes = t / 60
                form.seconds = t % 60
            }
            
        case .duration:
            if let firstSet = lastSets.first {
                form.sets = lastSets.count
                let t = firstSet.time ?? 0
                form.minutes = t / 60
                form.seconds = t % 60
            }
        }
    }
    
    func applyOverload() {
        form.weight = recommendedWeight
        showOverloadBanner = false
    }
    
    /// Генерирует готовый объект Exercise
    func generateExercise(unitsManager: UnitsManager) -> Exercise? {
        guard form.validate(for: exerciseType, unitsManager: unitsManager) else {
            showValidationAlert = true
            return nil
        }
        
        let setsCount = (exerciseType == .cardio) ? 1 : form.sets
        let totalSeconds = ((form.minutes ?? 0) * 60) + (form.seconds ?? 0)
        
        var generatedSets: [WorkoutSet] = []
        for i in 1...setsCount {
            generatedSets.append(WorkoutSet(
                index: i,
                weight: (exerciseType == .strength) ? form.weight : nil,
                reps: (exerciseType == .strength) ? form.reps : nil,
                distance: (exerciseType == .cardio) ? form.distance : nil,
                time: (totalSeconds > 0) ? totalSeconds : nil,
                isCompleted: false,
                type: .normal
            ))
        }
        
        return Exercise(
            name: exerciseName,
            muscleGroup: muscleGroup,
            type: exerciseType,
            sets: setsCount,
            reps: form.reps,
            weight: form.weight ?? 0.0,
            distance: form.distance,
            timeSeconds: totalSeconds > 0 ? totalSeconds : nil,
            effort: 5,
            setsList: generatedSets
        )
    }
}
