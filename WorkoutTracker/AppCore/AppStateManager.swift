

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
    var showGuestSignUpPrompt: Bool = false

    var requestedWidgetAction: String? = nil

    func showError(title: String, message: String) {
        self.currentError = AppError(title: title, message: message)
        
        // Convert to an NSError for Crashlytics non-fatal error logging
        let error = NSError(domain: "AppStateManager", code: -1, userInfo: [
            NSLocalizedDescriptionKey: message,
            "title": title
        ])
        TrackingManager.shared.recordError(error: error, additionalInfo: ["screen": "AppStateManager.showError"])
    }

    func clearError() {
        self.currentError = nil
    }
}
