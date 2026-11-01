import Testing
@testable import WorkoutTracker
import Foundation

@Suite("Haptic Manager")
struct HapticManagerTests {

    @Test("hapticsEnabled defaults to true when unset")
    func defaultsEnabled() {
        let defaults = UserDefaults(suiteName: "HapticManagerTests.\(UUID().uuidString)")!
        #expect(HapticManager.areHapticsEnabled(in: defaults) == true)
    }

    @Test("hapticsEnabled respects explicit false")
    func respectsDisabledFlag() {
        let defaults = UserDefaults(suiteName: "HapticManagerTests.\(UUID().uuidString)")!
        defaults.set(false, forKey: HapticManager.hapticsEnabledKey)
        #expect(HapticManager.areHapticsEnabled(in: defaults) == false)
        defaults.set(true, forKey: HapticManager.hapticsEnabledKey)
        #expect(HapticManager.areHapticsEnabled(in: defaults) == true)
    }
}
