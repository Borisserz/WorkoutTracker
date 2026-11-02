# Sister Apps Promo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show FoodTracker, Yoga, and FitRPG in Profile «More from us» plus a one-time sister-apps sheet after launch.

**Architecture:** Static `SisterAppsCatalog` + URL opener; Profile section driven by existing RC flag; replace FoodTracker-only fullScreenCover with `SisterAppsPromoView`; migrate `hasSeenFoodTrackerPromo` so existing users are not interrupted again.

**Tech Stack:** SwiftUI, String Catalog, Firebase Remote Config, XCTest, PastelTheme

## Global Constraints

- Pastel only; no CyberNeon / neon gradients; no decorative ALL-CAPS chrome
- EN String Catalog keys first; keep `ru` translations
- Gate haptics through `HapticManager`
- Default branch `develop`; ship also to `main`
- Store IDs: FoodTracker `6778506345`, Yoga `6795662863`, FitRPG `6785639478`
- Deep link only FoodTracker (`foodtracker://`); already in `LSApplicationQueriesSchemes`

## File map

| File | Role |
| --- | --- |
| `WorkoutTracker/Features/Promo/SisterAppsCatalog.swift` | Model + catalog + store URL + seen-flag helpers |
| `WorkoutTracker/Features/Promo/SisterAppsPromoView.swift` | One-time sheet UI |
| `WorkoutTracker/Features/Promo/SisterAppTile.swift` | Shared Profile/sheet row |
| `WorkoutTracker/Features/Profile/ProfileView.swift` | «More from us» section |
| `WorkoutTracker/AppCore/WorkoutTrackerApp.swift` | Present sheet + migration |
| `WorkoutTracker/AppCore/RemoteConfigManager.swift` | Alias `show_sister_apps_promo` |
| `WorkoutTracker/AppCore/UITestLaunchConfiguration.swift` | Set `hasSeenSisterAppsPromo` |
| `remote_config.json` | Document/alias key |
| `WorkoutTracker/Localizable.xcstrings` | EN + ru strings |
| `WorkoutTrackerTests/SisterAppsCatalogTests.swift` | Unit tests (+ pbxproj entry) |

---

### Task 1: Catalog + URL helpers (TDD)

**Files:**
- Create: `WorkoutTracker/Features/Promo/SisterAppsCatalog.swift`
- Create: `WorkoutTrackerTests/SisterAppsCatalogTests.swift`
- Modify: `WorkoutTracker.xcodeproj/project.pbxproj` (add test file like WatchConnectivityTests)

**Interfaces:**
- Produces: `SisterApp`, `SisterAppsCatalog.all`, `SisterAppsCatalog.appStoreURL(for:)`, `SisterAppsPromoFlags`

- [ ] **Step 1: Write failing tests**

```swift
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
        let defaults = UserDefaults(suiteName: "SisterAppsCatalogTests.\(UUID().uuidString)")!
        defaults.set(true, forKey: SisterAppsPromoFlags.legacyFoodTrackerSeenKey)
        XCTAssertTrue(SisterAppsPromoFlags.hasSeenPromo(defaults: defaults))
        SisterAppsPromoFlags.markSeen(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: SisterAppsPromoFlags.seenKey))
    }
}
```

- [ ] **Step 2: Run tests — expect fail (type not found)**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test -only-testing:WorkoutTrackerTests/SisterAppsCatalogTests
```

- [ ] **Step 3: Implement catalog**

```swift
import Foundation

struct SisterApp: Identifiable, Equatable, Sendable {
    let id: String
    let nameKey: String
    let taglineKey: String
    let symbolName: String
    let accent: Accent
    let appStoreId: String
    let urlScheme: String?

    enum Accent: String, Sendable {
        case peach, sage, lavender
    }
}

enum SisterAppsCatalog {
    static let all: [SisterApp] = [
        SisterApp(id: "foodtracker", nameKey: "Food Tracker", taglineKey: "Smart nutrition & AI coach",
                  symbolName: "fork.knife", accent: .peach, appStoreId: "6778506345", urlScheme: "foodtracker://"),
        SisterApp(id: "yoga", nameKey: "Yoga Coach & relax", taglineKey: "Daily yoga, breath, and calm",
                  symbolName: "figure.yoga", accent: .sage, appStoreId: "6795662863", urlScheme: nil),
        SisterApp(id: "fitrpg", nameKey: "FitRPG", taglineKey: "Real reps. Real damage.",
                  symbolName: "shield.lefthalf.filled", accent: .lavender, appStoreId: "6785639478", urlScheme: nil),
    ]

    static func appStoreURL(for app: SisterApp) -> URL? {
        URL(string: "https://apps.apple.com/app/id\(app.appStoreId)")
    }
}

enum SisterAppsPromoFlags {
    static let seenKey = "hasSeenSisterAppsPromo"
    static let legacyFoodTrackerSeenKey = "hasSeenFoodTrackerPromo"

    static func hasSeenPromo(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: seenKey) || defaults.bool(forKey: legacyFoodTrackerSeenKey)
    }

    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: seenKey)
        defaults.set(true, forKey: legacyFoodTrackerSeenKey)
    }
}
```

- [ ] **Step 4: Re-run tests — expect PASS**
- [ ] **Step 5: Commit** `test+feat: SisterAppsCatalog and promo flags`

---

### Task 2: Open helper + tile + promo sheet

**Files:**
- Create: `WorkoutTracker/Features/Promo/SisterAppStoreOpener.swift`
- Create: `WorkoutTracker/Features/Promo/SisterAppTile.swift`
- Create: `WorkoutTracker/Features/Promo/SisterAppsPromoView.swift`

**Interfaces:**
- Consumes: `SisterApp`, `SisterAppsCatalog`
- Produces: `SisterAppStoreOpener.open(_:)`, `SisterAppTile`, `SisterAppsPromoView`

- [ ] **Step 1: Test preferred open URL resolution**

```swift
func testPreferredOpenURLPrefersSchemeWhenProvided() {
    let app = SisterAppsCatalog.all[0]
    XCTAssertEqual(SisterAppStoreOpener.preferredURL(for: app, canOpenScheme: true)?.scheme, "foodtracker")
    XCTAssertEqual(SisterAppStoreOpener.preferredURL(for: app, canOpenScheme: false)?.host, "apps.apple.com")
}
```

- [ ] **Step 2: Implement opener + Pastel tiles + sheet**
  - Sheet title key `"More from us"`, subtitle `"Apps from the same team — take a look."`, dismiss `"Continue"`
  - Three `SisterAppTile` rows; tap opens store; Continue marks seen via dismiss
  - Use `PastelTheme` accents; `HapticManager.shared.impact(.light)` on taps
  - Button heights via `PastelTheme.ButtonMetrics`

- [ ] **Step 3: Run SisterAppsCatalogTests — PASS**
- [ ] **Step 4: Commit** `feat: sister apps opener, tiles, promo sheet`

---

### Task 3: Wire app launch + RC + UITest

**Files:**
- Modify: `WorkoutTracker/AppCore/WorkoutTrackerApp.swift`
- Modify: `WorkoutTracker/AppCore/RemoteConfigManager.swift`
- Modify: `WorkoutTracker/AppCore/UITestLaunchConfiguration.swift`
- Modify: `remote_config.json`

- [ ] **Step 1: RC** — `showSisterAppsPromo` = `show_sister_apps_promo` OR existing `show_foodtracker_promo`; keep writing `show_foodtracker_promo_enabled`
- [ ] **Step 2: App** — `@AppStorage` / state for sister sheet; show when RC on && `!SisterAppsPromoFlags.hasSeenPromo()`; on present call `markSeen`; replace `FoodTrackerPromoView` cover with `SisterAppsPromoView`
- [ ] **Step 3: UITest** — also set `hasSeenSisterAppsPromo = true`
- [ ] **Step 4: Commit** `feat: wire sister apps promo launch gate`

---

### Task 4: Profile «More from us»

**Files:**
- Modify: `WorkoutTracker/Features/Profile/ProfileView.swift`

- [ ] **Step 1: Replace single FoodTracker banner** with section header + `ForEach(SisterAppsCatalog.all)` tiles when `showFoodTrackerPromo` (shared defaults) is true
- [ ] **Step 2: Commit** `feat: Profile More from us sister app tiles`

---

### Task 5: Localization + verify + ship

**Files:**
- Modify: `WorkoutTracker/Localizable.xcstrings` (EN + ru for new strings)
- Modify: `docs/INDEX.md` (one line link to spec/plan)

- [ ] **Step 1: Add keys** — `More from us`, subtitle, app names/taglines if not already present, `Get`, `Continue`
- [ ] **Step 2: Build + test**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test -only-testing:WorkoutTrackerTests/SisterAppsCatalogTests
```

- [ ] **Step 3: Push branch, PR → develop, merge, fast-forward main**

---

## Spec coverage checklist

- [x] Catalog with three App Store IDs
- [x] Profile More from us
- [x] One-time sheet (not FoodTracker carousel clone)
- [x] Legacy seen migration
- [x] RC backward compatible
- [x] UITest skip
- [x] Tests + ship to main
