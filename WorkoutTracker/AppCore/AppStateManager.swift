// ============================================================
// FILE: WorkoutTracker/AppCore/AppStateManager.swift
// ============================================================

internal import SwiftUI
import SwiftData
import Observation

/// Отвечает исключительно за глобальное состояние UI (ошибки, глобальная навигация)
@Observable
@MainActor
final class AppStateManager {
    var currentError: AppError?
    
    // Глобальная навигация и баннер активной тренировки
    var selectedTab: Int = 0
    var isInsideActiveWorkout: Bool = false
    var returnToActiveWorkoutId: PersistentIdentifier? = nil
    
    func showError(title: String, message: String) {
        self.currentError = AppError(title: title, message: message)
    }
    
    func clearError() {
        self.currentError = nil
    }
}
