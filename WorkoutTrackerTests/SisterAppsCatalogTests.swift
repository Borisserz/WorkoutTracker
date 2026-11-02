import XCTest
@testable import WorkoutTracker

final class SisterAppsCatalogTests: XCTestCase {
    func testCatalogHasThreeAppsWithExpectedStoreIds() {
        let ids = SisterAppsCatalog.all.map(\.appStoreId)
        XCTAssertEqual(ids, ["6778506345", "6795662863", "6785639478"])
        XCTAssertEqual(SisterAppsCatalog.all.map(\.id), ["foodtracker", "yoga", "fitrpg"])
    }

    func testAppStoreURL() {
        let food = SisterAppsCatalog.all[0]
        XCTAssertEqual(
            SisterAppsCatalog.appStoreURL(for: food)?.absoluteString,
            "https://apps.apple.com/app/id6778506345"
        )
    }

    func testLegacyFoodTrackerSeenImpliesSisterSeen() {
        let suite = "SisterAppsCatalogTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: SisterAppsPromoFlags.legacyFoodTrackerSeenKey)
        XCTAssertTrue(SisterAppsPromoFlags.hasSeenPromo(defaults: defaults))
        SisterAppsPromoFlags.markSeen(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: SisterAppsPromoFlags.seenKey))
    }

    func testPreferredOpenURLPrefersSchemeWhenProvided() {
        let app = SisterAppsCatalog.all[0]
        XCTAssertEqual(SisterAppStoreOpener.preferredURL(for: app, canOpenScheme: true)?.scheme, "foodtracker")
        XCTAssertEqual(SisterAppStoreOpener.preferredURL(for: app, canOpenScheme: false)?.host, "apps.apple.com")
    }

    func testPreferredOpenURLFallsBackWhenNoScheme() {
        let yoga = SisterAppsCatalog.all[1]
        XCTAssertEqual(
            SisterAppStoreOpener.preferredURL(for: yoga, canOpenScheme: true)?.absoluteString,
            "https://apps.apple.com/app/id6795662863"
        )
    }
}
