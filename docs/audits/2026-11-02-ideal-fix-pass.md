# Ideal audit fix pass — 2026-11-02

Branch: `fix/ideal-audit-pass`

## Verdict

Code-fixable P0–P2 findings from the 2026-11-02 full-app audit are closed. `WorkoutTrackerTests` **TEST SUCCEEDED** on iPhone 17 Simulator.

## Closed

| Area | Change |
|------|--------|
| CNS honesty | `Constants.CNS.unmeasuredAppStorageDefault = -1`; AI Hub + Overview AppStorage aligned |
| Locale | Calendar/History use `Locale.autoupdatingCurrent`; weekday strip locale-aware |
| Perf | `fetchLimit` 400 Progress/AICoach/Overview; Calendar 800 |
| L10n | AI Hub / Progress / Calendar RU hardcodes → EN catalog + `ru` |
| Session | AI start uses returned PID; Watch `.startWorkout` shares `startInFlight`; History uses `isStartBlocked` |
| AI UX | No “Google” 5xx copy; on-device camera without cloud consent; chat Stop |
| Polish | `#if DEBUG` prints (Watch/HK/ML); removed dead `calculateOptimalRecoveryTime`; share-card anti-slop |

## Ops still manual

1. Rotate FatSecret credentials if they were ever live in git history.
2. Confirm Archive `aps-environment=production`.
3. Physical device + Watch smoke.

## Evidence

```text
xcodebuild … test -only-testing:WorkoutTrackerTests
** TEST SUCCEEDED **
```
