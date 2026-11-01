# Residual Fix Status — 2026-11-01

**Source findings:** [`2026-11-01-residual-report.md`](2026-11-01-residual-report.md)  
**ADR:** [`../adr/0001-session-safety-cns-signout.md`](../adr/0001-session-safety-cns-signout.md)  
**Branch:** `fix/post-redesign-audit`  
**Overall:** **CLOSED** (R01–R14 + J01–J16)

---

## Breaks

| ID | Status | Notes |
|----|--------|-------|
| R01 | Fixed | Watch `.startWorkout` refuses when phone has fresh active session |
| R02 | Fixed | Sign-out no longer calls `deleteLocalData` (CloudKit-safe) |
| R03 | Fixed | `startGeneratedWorkout` / `createWorkout` central active-session guard |
| R04 | Fixed | Empty active session deleted on Detail disappear |
| R05 | Fixed | History replay uses `Exercise(from: toDTO())` like Hub |
| R06 | Fixed | BlockedUsersStore one-shot hydrate + restart after sign-out |
| R07 | Fixed | Overview passes raw CNS; engine handles `< 0` as not measured |
| R08 | Fixed | CNSCalculator returns `-1` when HRV+RHR missing; no invented component points |
| R09 | Fixed | Stale empty → delete; stale with sets → real elapsed (not +1h) |
| R10 | Fixed | Analytics fetch on main context |
| R11 | Fixed | Watch active-state uses `transferUserInfo` fallback; preset save logs errors |
| R12 | Fixed | Widget decoder defaults empty muscles/tip |
| R13 | Fixed | Account wipe parity with Clear All + avatar + XP + widget |
| R14 | Fixed | Root `onOpenURL` handles warm deep links |

## Improve

| ID | Status | Notes |
|----|--------|-------|
| J01–J05 | Fixed | Share card / Live Activity / stats sheets / Saved / StatsWidget polish |
| J06–J08 | Fixed | Analytics counts + start track; start returns ID; rest button uses defaultRest |
| J09 | Fixed | Appearance section (dark-only) |
| J10 | Fixed | Export presets / notes / chat / colors |
| J11 | Fixed | Widget streak from full history |
| J12–J13 | Fixed | `GIDSignIn.signOut` + bootstrap error UI |
| J14 | Fixed | AI save errors + SetRow AI consent |
| J15 | Partial | `ResidualPassTests` + `ImprovePassSmokeTests` in target; deeper Watch/export suites still optional |
| J16 | Fixed | Legacy `WorkoutView`: no mock rows + delete confirm |

## Key code touchpoints

- `WorkoutService` — active guards, returned IDs, Watch start refuse
- `WorkoutStore.findActiveWorkoutsAndCleanup` — honest stale close
- `CNSCalculator` / `BodyAnalysisEngine` / `OverviewView` — unknown CNS
- `WidgetDataShared` / `WidgetSyncService` — no fake tip; full streak window
- `SettingsView` / `BlockedUsersStore` / `SocialAuthService` — sign-out & wipe
- `WorkoutDetailView` / `HistoryView` — ghost empty + DTO replay
- `WorkoutTrackerApp` — warm `onOpenURL` + bootstrap error

## Verification evidence

```text
BUILD SUCCEEDED  — iPhone 17 Simulator (iOS 26.3.x)
TEST SUCCEEDED   — ResidualPassTests (5) + ImprovePassSmokeTests (3) + CNSCalculatorTests
```

## Follow-up polish (same day)

See [`2026-11-01-polish-pass.md`](2026-11-01-polish-pass.md) — P0 CNS/recovery/Watch saves + P1 Pastel/i18n/Explore honesty closed.

## Still optional (not blockers)

- Broader onboarding RU beyond Feature Discovery
- MLVision debug print localization
- Dedicated WatchConnectivity unit suite
- Device smoke: empty Detail dismiss → no active banner; Watch start while phone active
