

import AppIntents
internal import SwiftUI

struct OpenWorkoutAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Workout Action"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Action Type")
    var actionType: String

    init() {}

    init(actionType: String) {
        self.actionType = actionType
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Persist first — NotificationCenter is lost if mainContent is not mounted yet (B17).
        // App Group so widget extension + main app share the same key (Constants may be unavailable here).
        let key = "pendingWidgetAction"
        let suite = UserDefaults(suiteName: "group.com.borisdev.WorkoutTracker")
        suite?.set(actionType, forKey: key)
        UserDefaults.standard.set(actionType, forKey: key)
        NotificationCenter.default.post(
            name: Notification.Name("widgetActionTriggered"),
            object: actionType
        )
        return .result()
    }
}
