# Sister apps promo — design

**Date:** 2026-11-02  
**Status:** Approved (approach A)  
**Branch target:** `develop` → `main`

## Goal

Cross-promote the other apps from the same developer inside WorkoutTracker:

| App | App Store ID | Tagline (EN) |
| --- | --- | --- |
| FoodTracker | `6778506345` | Smart nutrition & AI coach |
| Yoga Coach & relax | `6795662863` | Daily yoga, breath, and calm |
| FitRPG | `6785639478` | Real reps. Real damage. |

Sources of truth for store links: GitHub READMEs / Apple developer listing (same IDs as above).

## Non-goals

- Settings placement (rejected; Profile only)
- Rebuilding the long FoodTracker cosmic carousel for Yoga/FitRPG
- Server-driven app list JSON (static catalog is enough for three apps)
- Deep links for Yoga/FitRPG unless a known scheme is confirmed (FoodTracker keeps `foodtracker://`)

## Approach A (chosen)

Single catalog + Profile tiles + one shared one-time sheet.

### 1. `SisterAppsCatalog` (pure data)

`WorkoutTracker/Features/Promo/SisterAppsCatalog.swift` (or under `AppCore/`):

```swift
struct SisterApp: Identifiable, Equatable {
    let id: String            // stable: "foodtracker" | "yoga" | "fitrpg"
    let name: String          // String Catalog key source
    let tagline: String
    let symbolName: String
    let accentToken: String   // maps to PastelTheme color in UI
    let appStoreId: String
    let urlScheme: String?    // e.g. "foodtracker://"
}
```

Static `SisterAppsCatalog.all` ordered: FoodTracker, Yoga, FitRPG.

`SisterAppStoreOpener.open(_ app)`:

1. If `urlScheme` present and `canOpenURL` → open scheme  
2. Else open `https://apps.apple.com/app/id{appStoreId}`

Register `foodtracker` in `LSApplicationQueriesSchemes` if not already (required for `canOpenURL`).

### 2. Profile — «More from us»

Replace the single FoodTracker-only banner gate with a section at the bottom of `ProfileView`:

- Header: `More from us`
- Three compact tiles (reuse Pastel card language; no neon, no ALL-CAPS chrome beyond existing small GET chip if kept tasteful — prefer “Get” title-case)
- Visibility: same Remote Config boolean as today (`show_foodtracker_promo` / shared defaults key), so ops can kill the section without a release
- Always show all three when the flag is on (do not hide installed apps for v1 — simpler; opener still deep-links FoodTracker when installed)

### 3. One-time full-screen intro

Replace FoodTracker-only `FoodTrackerPromoView` presentation path with `SisterAppsPromoView`:

- Shown once after launch when RC flag is on and `hasSeenSisterAppsPromo == false`
- Migrate: if `hasSeenFoodTrackerPromo` already true → treat sister promo as already seen (no second interrupt for existing users)
- UITest / `-UITestMode`: set seen flag true (extend `UITestLaunchConfiguration`)
- Layout: Pastel dark sheet — title “More from us”, short subtitle, three tappable app rows, primary dismiss “Continue”, optional per-row Get
- Do **not** port the motion/parallax FoodTracker carousel into this sheet (keep it small and honest). Leave `FoodTrackerPromoView.swift` in tree unused or delete only if nothing references it after cutover

### 4. Remote Config

- Keep reading `show_foodtracker_promo` (default `1` in `remote_config.json`) for backward compatibility
- Optionally alias `show_sister_apps_promo` → same bool (OR of both); document in RC comment
- Shared App Group key remains `show_foodtracker_promo_enabled` unless a clean rename is cheap; if renaming, write both keys during fetch for one release

### 5. Localization

EN String Catalog keys for section title, sheet copy, app names/taglines; add `ru` (and existing locales) in `Localizable.xcstrings`.

### 6. Testing

- Unit: catalog has three apps with expected App Store IDs; opener URL builder returns expected store URL; migration: `hasSeenFoodTrackerPromo` implies sister seen
- Build: `xcodebuild` Debug for iPhone 17 simulator (or generic iOS)
- Manual / Maestro optional: Profile shows section when flag on; UITestMode skips sheet

### 7. Ship

Commit on feature branch → PR into `develop` → merge → fast-forward `main` to match (repo default branch remains `develop`).

## Out of scope for follow-ups

- Per-app RC toggles
- Hide-if-installed logic
- Marketing screenshots inside the sheet
