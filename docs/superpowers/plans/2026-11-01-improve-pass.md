# Improve pass (I01–I20) Implementation Plan

> **For agentic workers:** After each group: `xcodebuild` Debug → iPhone 17 / iOS 26.3.1. No commit unless asked.

**Goal:** Close Improve backlog from `docs/audits/2026-11-01-full-report.md` without rewriting Hub/Overview.

**Architecture:** Extend PastelTheme + EN String Catalog keys; gate haptics via `HapticManager`; keep dark-only.

## Groups (order)

| Group | IDs | Done when |
|-------|-----|-----------|
| G1 i18n | I01, I02, I19 + leftover AICoach/Progress RU | **DONE** — Cyrillic cleared on listed surfaces |
| G2 theme/haptics | I03, I04, I14, I20 | **DONE** — Pastel widget; HapticManager gated; dark-lock menu; Title Case |
| G3 data/settings | I05, I06, I07, I09 | **DONE** — Clear All / export / activityLevel / History confirm |
| G4 AI/camera/version | I08, I10–I13, I15, I16 | **DONE** — guest copy, consent/errors, camera Retry, version/RC/auth/scene |
| G5 polish | I17, I18 | **DONE** (I18 earlier; I17 smoke tests; deeper migrator suite later) |

**Verification evidence:** `BUILD SUCCEEDED` + `TEST SUCCEEDED` (iPhone 17 / iOS 26.3.1).

**Follow-up:** Residual audit R/J pass also closed — see `docs/audits/2026-11-01-residual-fix-status.md` and `docs/INDEX.md`.

## Verification

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test -only-testing:WorkoutTrackerTests
```
