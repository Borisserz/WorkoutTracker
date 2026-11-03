# Readiness verify + harden — 2026-11-03

**Spec:** [`../superpowers/specs/2026-11-03-readiness-hardening-design.md`](../superpowers/specs/2026-11-03-readiness-hardening-design.md)  
**Plan:** [`../superpowers/plans/2026-11-03-readiness-hardening.md`](../superpowers/plans/2026-11-03-readiness-hardening.md)

## Verdict

**Conditionally ready** for App Store submit.

Code + Simulator regression gates are green. Ship blockers that remain are **ops / hardware** (human): FatSecret rotate, Archive push entitlement, device+Watch smoke.

## Evidence

| Gate | Result |
|------|--------|
| `WorkoutTrackerTests` on iPhone 17 Simulator | **TEST SUCCEEDED** (Watch embed temporarily detached — no `watchsimulator` runtime on this Mac; `project.pbxproj` restored after) |
| Maestro `smoke` | **13/13 Passed** (~6m 36s) |
| Maestro `workout` | **7/7 Passed** (~5m 43s), includes `workout_log_set_finish` (deep) |
| Session dual-start / finish-undo | Guards present (`startInFlight`, `finishTransitionDepth`); covered by `ResidualPassTests` + `WatchConnectivityTests` — **no code change** |

### Commands

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# Unit (same Watch detach pattern as prior 2026-11-03 audits if no watchOS runtime)
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test -only-testing:WorkoutTrackerTests

./scripts/maestro_run.sh smoke
./scripts/maestro_run.sh workout
```

## Hardening shipped this pass

1. **`scripts/maestro_run.sh`**
   - Deterministic `-derivedDataPath .derivedData/maestro` (no stale DerivedData `.app`)
   - Auto-detach / restore Watch embed when no watchOS Simulator runtime (`trap` + `git checkout`)
   - Validates `CFBundleIdentifier` before `simctl install`
2. **A11y roots for Maestro** — `wt.aihub.root`, `wt.aihub.settings`, `wt.progress.root`, `wt.calendar.root`, `wt.recovery.root`
3. **Maestro copy sync** — AI Hub / Progress / Recovery asserts match current Pastel UI strings
4. **`.gitignore`** — `.derivedData/`

## Human ops checklist (before / during submit)

Copy from [`2026-11-01-prod-readiness.md`](2026-11-01-prod-readiness.md); check off when done:

- [ ] **R-02** Rotate FatSecret credentials (were in git history) + set only in Firebase Remote Config
- [ ] **R-01** Archive with distribution profile; confirm Archive entitlements `aps-environment` = `production`
- [ ] **R-05** Physical device + Watch smoke — [`2026-11-02-watch-device-smoke.md`](2026-11-02-watch-device-smoke.md) (~15 min)
- [ ] **R-04** App Review notes (demo account if gated; HealthKit optional; Watch optional)
- [ ] Optional: install local `watchOS` Simulator runtime so Watch detach is unnecessary for CI/dev

## Out of scope (unchanged)

- OpenRouter migration, mass `print` → `os.Logger`, full `maestro_run.sh all` as hard gate, Watch/Live Activity in Maestro

## Next action

1. You: run the ops checklist above (~30–60 min).  
2. Say «коммит» if you want this pass committed (docs + Maestro script + a11y + flow copy).
