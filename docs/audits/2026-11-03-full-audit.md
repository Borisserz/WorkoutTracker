# Full-app audit — 2026-11-03

Branch: `develop`  
Method: code review (core / AI / l10n / UX / perf+Watch+widget) against ADR-0001 + prior closed audits.

## Verdict

**Core product ~8.5/10.** No runtime P0 blockers in session/CNS/sign-out/widget honesty. Ship blockers remain **ops** (FatSecret rotate, Archive `aps-environment`, device+Watch smoke). This pass closes code P1s listed under Fix status.

## Feature matrix

| Area | Status | Notes |
|------|--------|-------|
| Overview / vitals | OK | CNS honesty; header locale fixed this pass |
| Hub / start paths | OK | Single-session guards |
| Active workout / finish | OK | |
| History | Fixed P1 | Locale formatters + filter/timeline localization |
| Progress | Fixed P1 | Haptics via `HapticManager` |
| AI Hub / chat / Smart Builder | Fixed P1 | Unmeasured CNS greeting honesty |
| Explore / Legendary | Partial | Content = Firestore |
| Profile / Settings | OK | Sign-out ≠ wipe |
| Widgets | OK | No invented tip/muscles |
| Watch | Fixed P1 | `isSessionStartBlocked` includes `isStartBlocked` |
| Auth / FatSecret | Ops | Rotate if ever live in git |

## Findings

### Ops P0 (manual)

1. Rotate FatSecret credentials if they were in git history.
2. Archive: confirm `aps-environment=production`.
3. Physical iPhone + Watch smoke (~15 min) — see `2026-11-02-watch-device-smoke.md`.

### P1 (code — this pass)

| ID | Issue | Fix |
|----|-------|-----|
| A01 | AI Hub treats CNS `-1` as fatigue | `CNSCalculator.coachGreeting` + `getStatus` unmeasured branch |
| A02 | Watch `canStartWorkout` ignores phone `startInFlight` | Wire `isSessionStartBlocked` → `workoutService.isStartBlocked` |
| A03 | History `en_US`/`ru_RU` + `Text(rawValue)` | Autoupdating locale + localized titles |
| A04 | Overview missing `ru` + header POSIX date | Catalog `ru` + autoupdating header |
| A05 | Progress bypasses `HapticManager` (17) | Route through `HapticManager` |
| A06 | Hub/History CTA height 32 | `ButtonMetrics.inCardHeight` (36) |
| A07 | `DynamicWorkoutListView` unbounded `@Query` | `fetchLimit` 400 |

### P2 (closed in follow-up pass)

- Multi-active heal (&lt;12h) in `WorkoutStore`
- Removed dead `WorkoutConfigSheet` / `BestExercisesSheet`; Progress/Weekly AI consent gates
- GifImageView skip reload when URL unchanged
- WatchWorkoutStore predicate + `fetchLimit = 1`
- Anti-slop: ALL-CAPS / middle dots on Progress/ProgramDetail; Settings → Muscle colors; removed orphan OverviewRouter cases

## Fix status (this pass)

| ID | Status |
|----|--------|
| A01–A07 | **Fixed** in working tree on `develop` |
| Ops P0 | Still manual |
| P2 | Deferred |

## Evidence

```text
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,id=6179F736-…' \
  -configuration Debug test -only-testing:WorkoutTrackerTests
** TEST SUCCEEDED **
```

Note: local machine lacks `watchsimulator` runtime; verification temporarily skipped Watch embed dependency for the iOS test run, then restored `project.pbxproj` (no Watch change committed).
