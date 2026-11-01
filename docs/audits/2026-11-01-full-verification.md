# Full-app verification — 2026-11-01

Branch: `fix/post-redesign-audit`  
Device: iPhone 17 Pro Simulator (`83F3F71D-73B0-4255-A9A5-59BB71268BB5`), iOS 26.1  
Bundle: `com.borisdev.WorkoutTracker` (display name **Ai Workout**)

## Verdict

**Pass.** Build green, 46/46 unit tests green, static health checks clean, main tabs launch and render Pastel dark UI without crash. First-launch system sheets (Health / Notifications / Speech) behave as expected; they are not app bugs.

## Evidence

| Check | Result | Proof |
|-------|--------|-------|
| Debug build (iOS Simulator) | SUCCEEDED | `xcodebuild -scheme WorkoutTracker -destination 'id=2B6F9CB3-…' -quiet build` exit 0 |
| `WorkoutTrackerTests` | **46 passed / 0 failed** | `/tmp/wt-test.log` (`passed on` ×46, no `failed on`) |
| Residual / Improve / CNS honesty | covered by suite | `ResidualPassTests`, `ImprovePassSmokeTests`, `CNSCalculatorTests`, `AppearanceModeTests` |
| `fatalError` in app sources | none | `rg fatalError WorkoutTracker/` empty |
| `CyberNeon` / neon accents | none | `rg CyberNeon` empty |
| Appearance locked dark | yes | `AppearanceMode.lockedRawValue = "dark"` |
| Cyrillic hard-coded UI | only intentional locale label + comment | Settings language row; AITracker comment |
| Sim launch | app boots | pid launch after install |
| Workout Hub UI | OK | `/tmp/wt-smoke/11-relaunched.png`, `final-workout-hub.png` — Start workout, calendar strip, Legendary programs, tab bar |
| Progress tab | OK (behind Speech sheet) | `/tmp/wt-smoke/final-current.png` — Progress header, Awards 0 of 12, Goals |
| Activity calendar empty state | OK | `/tmp/wt-smoke/calendar.png` — 0 streak / 0 workouts |
| Overview / tabs earlier smoke | OK | `/tmp/wt-smoke/main-tabs.png`, `tab-0`…`tab-4` from same-day pass |

## Smoke notes (not failures)

1. **Health Access + Notifications** on fresh install — expected; `simctl privacy grant health|notifications` returns *Operation not permitted* on this host.
2. **`simctl openurl workouttracker://…`** often shows system “Open in Ai Workout?” — Simulator quirk; Cancel/Open both fine.
3. **Speech Recognition** prompt can appear when Progress / voice features load — expected TCC.
4. **Locale mix**: system date may be Russian while EN catalog strings stay English — String Catalog design, not a regression.
5. **WatchConnectivity dedicated unit suite** and **physical device** smoke were not run in this pass (optional follow-ups).

## Static honesty checks (reconfirmed)

- Empty recovery map ≠ “100% prime” (`BodyAnalysisEngine` comment + Residual tests).
- CNS without HRV+RHR → unknown / not measured (Residual + CNS tests).
- Widget decode does not invent tip/muscles (Residual tests).
- No `fatalError` after `databaseLoadError` set.

## What’s left (optional)

1. Physical iPhone smoke (HealthKit real data, Watch pairing).
2. WatchConnectivity unit coverage.
3. Commit on user «коммит» — large uncommitted tree on this branch.

## Commands to re-run

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -scheme WorkoutTracker -destination 'generic/platform=iOS' -quiet build
xcodebuild test -scheme WorkoutTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:WorkoutTrackerTests
```
