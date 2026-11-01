import XCTest
@testable import WorkoutTracker

final class ImprovePassSmokeTests: XCTestCase {
    func testAppearanceModeAlwaysDark() {
        XCTAssertEqual(AppearanceMode.resolved("light"), "dark")
        XCTAssertEqual(AppearanceMode.resolved("system"), "dark")
        XCTAssertEqual(AppearanceMode.lockedRawValue, "dark")
    }

    func testHapticsDefaultEnabled() {
        let defaults = UserDefaults(suiteName: "ImprovePassSmokeTests.haptics")!
        defaults.removePersistentDomain(forName: "ImprovePassSmokeTests.haptics")
        XCTAssertTrue(HapticManager.areHapticsEnabled(in: defaults))
        defaults.set(false, forKey: HapticManager.hapticsEnabledKey)
        XCTAssertFalse(HapticManager.areHapticsEnabled(in: defaults))
    }

    func testWidgetDataPreservesTipWhenReloaded() {
        let tip = "Keep shoulders packed."
        WidgetDataManager.save(
            streak: 3,
            weeklyStats: [.init(label: "Mon", count: 1)],
            recoveredMuscles: ["Chest"],
            aiTip: tip,
            totalVolumeTons: 1.25
        )
        let loaded = WidgetDataManager.load()
        XCTAssertEqual(loaded.aiTip, tip)
        XCTAssertEqual(loaded.recoveredMuscles, ["Chest"])
        XCTAssertEqual(loaded.totalVolumeTons, 1.25, accuracy: 0.001)
    }
}
