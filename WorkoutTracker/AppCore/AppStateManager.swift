//
//  AppStateManager.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 3.04.26.
//

//
//  AppStateManager.swift
//  WorkoutTracker
//

internal import SwiftUI
import Observation

/// Отвечает исключительно за глобальное состояние UI (ошибки, глобальные лоадеры и т.д.)
@Observable
@MainActor
final class AppStateManager {
    var currentError: AppError?
    
    func showError(title: String, message: String) {
        self.currentError = AppError(title: title, message: message)
    }
    
    func clearError() {
        self.currentError = nil
    }
}
