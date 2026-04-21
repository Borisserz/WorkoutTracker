

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
        NotificationCenter.default.post(
            name: Notification.Name("widgetActionTriggered"),
            object: actionType
        )
        return .result()
    }
}
