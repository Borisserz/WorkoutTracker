

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
    var pendingOpenURL: URL? = nil
    var showWorkoutModeDiscovery: Bool = false
    var showProfileSheet: Bool = false
    var showAchievementsSheet: Bool = false
    var showCalendarSheet: Bool = false
    var showSmartBuilder: Bool = false
    var showWeightLog: Bool = false
    var showSmartBuilderSheet: Bool = false
    var showAISettingsSheet: Bool = false

    func showError(title: String, message: String, underlyingError: Error? = nil) {
        self.currentError = AppError(title: title, message: message)

        if let underlyingError {
            TrackingManager.shared.recordError(
                error: underlyingError,
                additionalInfo: [
                    "screen": "AppStateManager.showError",
                    "alert_title": title,
                    "alert_message": message
                ]
            )
            return
        }

        let safeTitle = title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let domain = safeTitle.isEmpty ? "AppStateManager" : "AppStateManager.\(safeTitle)"
        let error = NSError(domain: domain, code: -1, userInfo: [
            NSLocalizedDescriptionKey: message,
            "title": title
        ])
        TrackingManager.shared.recordError(error: error, additionalInfo: ["screen": "AppStateManager.showError"])
    }

    func clearError() {
        self.currentError = nil
    }
}
