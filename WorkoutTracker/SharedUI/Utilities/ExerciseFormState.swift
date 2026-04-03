//
//  ExerciseFormState.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 1.04.26.
//

import Foundation

/// Структура, инкапсулирующая состояние и логику валидации для формы создания упражнения.
struct ExerciseFormState {
    
    // MARK: - Form Data
    
    var sets: Int = 3
    var reps: Int = 10
    var weight: Double? = nil
    var distance: Double? = nil
    var minutes: Int? = 0
    var seconds: Int? = 0
    
    // MARK: - Validation State
    
    var validationErrorMessage: String? = nil
    var isValid: Bool { validationErrorMessage == nil }
    
    // MARK: - Validation Logic
    
    /// Валидирует текущие значения формы и обновляет состояние ошибок.
    /// - Returns: `true` если все поля валидны, иначе `false`.
    mutating func validate(for type: ExerciseType, unitsManager: UnitsManager) -> Bool {
        var errorMessages: [String] = []
        
        // --- Валидация для Силовых ---
        if type == .strength {
            let actualWeight = weight ?? 0.0
            let weightValidation = InputValidator.validateWeight(actualWeight)
            if !weightValidation.isValid {
                errorMessages.append(weightValidation.errorMessage ?? "Invalid weight")
                weight = weightValidation.clampedValue
            }
            
            let repsValidation = InputValidator.validateReps(reps)
            if !repsValidation.isValid {
                errorMessages.append(repsValidation.errorMessage ?? "Invalid reps")
                reps = repsValidation.clampedValue
            }
        }
        
        // --- Валидация для Кардио ---
        if type == .cardio {
            let actualDistance = distance ?? 0.0
            let distValidation = InputValidator.validateDistance(actualDistance)
            if !distValidation.isValid {
                errorMessages.append(distValidation.errorMessage ?? "Invalid distance")
                distance = distValidation.clampedValue
            }
        }
        
        // --- Общая валидация времени ---
        let totalSeconds = ((minutes ?? 0) * 60) + (seconds ?? 0)
        if totalSeconds > 0 {
            let timeValidation = InputValidator.validateTime(totalSeconds)
            if !timeValidation.isValid {
                errorMessages.append(timeValidation.errorMessage ?? "Invalid time")
                minutes = timeValidation.clampedValue / 60
                seconds = timeValidation.clampedValue % 60
            }
        }
        
        // --- Финальное обновление состояния ---
        if errorMessages.isEmpty {
            validationErrorMessage = nil
            return true
        } else {
            validationErrorMessage = errorMessages.joined(separator: "\n")
            return false
        }
    }
}
