

internal import SwiftUI
import SwiftData
import Observation

@Observable
@MainActor
final class AppStateManager {
    var currentError: AppError?

    var selectedTab: Int = 2

    var isInsideActiveWorkout: Bool = false
    var returnToActiveWorkoutId: PersistentIdentifier? = nil

    var requestedWidgetAction: String? = nil

    func showError(title: String, message: String) {
        self.currentError = AppError(title: title, message: message)
    }

    func clearError() {
        self.currentError = nil
    }
}
