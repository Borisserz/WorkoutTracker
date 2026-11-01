# Production readiness review — 2026-11-01

Branch: `fix/post-redesign-audit`  
Scope: WorkoutTracker iOS + Watch + widgets (codebase + feature honesty)

## Verdict

**Conditionally ready for App Store submit after the fixes in this pass.** Core session/CNS/sign-out/widget honesty paths are sound. Follow-up from deep audit closed: fail-closed `hasActiveWorkout`, start serialization, widget no invented rest/muscles, Watch `canStartWorkout` handshake.

## Fixed this pass

| ID | Severity | Issue | Fix |
|----|----------|-------|-----|
| P-01 | BLOCKER (honesty) | Sign Out alert claimed it would wipe device data; code does not wipe (ADR R02) | Honest EN (+ locales) copy in Settings + String Catalog |
| P-02 | HIGH | Watch `try! ModelContainer` crash on store failure | Disk → in-memory fallback in `WatchApp/App/WorkoutTrackerWatchApp.swift` |
| P-03 | HIGH | FatSecret client id/secret committed in `remote_config.json` defaults | Cleared defaults; set values only in Firebase console; **rotate those keys** if they were ever live |
| P-04 | MED | Remote Config `print` in Release | `#if DEBUG` gated |
| P-05 | HIGH (ops) | Delete Profile alert understated CloudKit / server scope | Stronger warning: local (+ possible iCloud sync); server needs Delete Account |

## Verified OK

- Single active workout guards (`WorkoutService` create / AI start / Watch `.startWorkout` refuse)
- CNS / anatomy / widget: no invented readiness when vitals missing (tests + prior ideal pass)
- Sign-out does **not** call `deleteLocalData()`; wipe on Delete Account / Delete Profile / DEBUG Clear All
- `databaseLoadError` path shows UI (no `fatalError` after recoverable state)
- DEBUG-only Clear All / Test Data section
- Privacy usage strings: Health, Camera, Mic, Speech, Photos
- `PrivacyInfo.xcprivacy` in app target Resources; `NSPrivacyTracking = false`
- Force update checks live in Release (DEBUG/sim skip unless `forceUpdateTestingEnabled`)
- MARKETING_VERSION `1.0.5` aligned with `minimum_ios_version` default `1.0.5`

## Remaining before / during submit

| ID | Severity | Item | Action |
|----|----------|------|--------|
| R-01 | HIGH | `aps-environment` = `development` in entitlements | Archive with distribution profile; confirm Archive entitlements show `production` for push |
| R-02 | HIGH | FatSecret secrets were in git history | Rotate FatSecret credentials in provider + Firebase RC |
| R-03 | MED | ~86 ungated `print` in Release (services/ML) | Optional: wrap or replace with `os.Logger` / Crashlytics breadcrumbs |
| R-04 | MED | App Review notes | Demo Apple/Google account if gated; note HealthKit optional; Watch optional |
| R-05 | MED | Physical device + Watch smoke | HealthKit, WatchConnectivity, Live Activity, push |
| R-06 | LOW | Locale: system date RU vs EN catalog | Expected; not a blocker |
| R-07 | LOW | `GoogleService-Info.plist` client API key in repo | Normal for Firebase iOS; restrict key in Google Cloud console |

## Feature readiness (prod)

| Area | Status |
|------|--------|
| Overview / vitals honesty | Ready |
| Workout Hub start paths | Ready (single-session) |
| History / calendar empty states | Ready |
| Progress / awards empty | Ready |
| Settings auth / export / delete | Ready after copy fixes |
| AI Coach / camera | Ready with permission sheets |
| Widgets | Ready (no invented tip/muscles) |
| Watch companion | Ready after container fallback; device QA still needed |
| FoodTracker promo | Flag-driven; FatSecret creds must live in RC console |

## Next action

1. Rotate FatSecret keys if they were production values.  
2. Archive once; confirm push entitlement = production.  
3. Device smoke checklist (R-05).  
4. User «коммит» when ready to commit this branch.
