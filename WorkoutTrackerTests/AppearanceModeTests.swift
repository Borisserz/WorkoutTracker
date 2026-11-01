import Testing
@testable import WorkoutTracker
import Foundation

@Suite("Appearance Mode")
struct AppearanceModeTests {

    @Test("Any stored preference resolves to locked dark")
    func resolvesToDark() {
        #expect(AppearanceMode.resolved("light") == "dark")
        #expect(AppearanceMode.resolved("system") == "dark")
        #expect(AppearanceMode.resolved("dark") == "dark")
        #expect(AppearanceMode.resolved(nil) == "dark")
        #expect(AppearanceMode.resolved("") == "dark")
    }

    @Test("Enforcing lock writes dark into UserDefaults")
    func enforcesUserDefaults() {
        let defaults = UserDefaults(suiteName: "AppearanceModeTests.\(UUID().uuidString)")!
        defaults.set("light", forKey: AppearanceMode.userDefaultsKey)
        AppearanceMode.enforceLockedModeInUserDefaults(defaults: defaults)
        #expect(defaults.string(forKey: AppearanceMode.userDefaultsKey) == "dark")
    }
}
