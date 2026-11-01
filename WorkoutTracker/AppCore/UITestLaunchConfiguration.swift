import Foundation

/// Launch-argument harness for Maestro / UI tests.
/// Pass `-UITestMode` so the app skips onboarding and system permission prompts.
enum UITestLaunchConfiguration {
    static var isUITestMode: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-UITestMode") || args.contains("UITestMode") { return true }
        // Maestro may pass `-UITestMode true` as adjacent argv pairs.
        if let idx = args.firstIndex(of: "-UITestMode"), args.index(after: idx) < args.endIndex {
            return args[args.index(after: idx)].lowercased() != "false"
        }
        return ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
    }

    /// Call as early as possible (AppDelegate) before SwiftUI `@AppStorage` reads.
    static func applyIfNeeded() {
        guard isUITestMode else { return }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasCompletedGodModeOnboarding_v1")
        defaults.set(true, forKey: "hasSeenFeatureDiscovery")
        defaults.set(true, forKey: "hasSeenFoodTrackerPromo")
        defaults.set(true, forKey: "hasSeenCommitmentSheet")
        // Skip AI consent sheet so Hub chrome flows can open chat/tools.
        defaults.set(true, forKey: Constants.UserDefaultsKeys.hasConsentedToAI.rawValue)
        // Avoid guest sign-up sheet after first finished workout in Maestro.
        defaults.set(true, forKey: "hasSeenGuestSignUpPrompt")
        // Dark-only lock already enforced by AppearanceMode; keep explicit for suites.
        defaults.set(AppearanceMode.lockedRawValue, forKey: Constants.UserDefaultsKeys.appearanceMode.rawValue)
    }
}
