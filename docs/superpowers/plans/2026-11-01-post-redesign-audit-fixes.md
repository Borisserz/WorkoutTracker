# Post-redesign audit fixes

> **For agentic workers:** Use TDD for testable logic (appearance lock, haptics gate). UI string swaps verified by build.

**Goal:** Close P0–P2 from colleague redesign audit without redoing Hub/Overview.  
**Status:** **DONE** — continued into full Breaks / Improve / Residual passes (`docs/INDEX.md`).

## Tasks
1. ~~Appearance: force `dark` only in settings + normalize AppStorage~~
2. ~~Remove `fatalError` after ModelContainer failure~~
3. ~~Wire Clear All alert to `clearAllWorkouts()`~~
4. ~~Localize tab bar + key RU chrome (EN source keys)~~
5. ~~Delete `CyberNeonTheme`; Pastel-sweep Progress/promo leftovers~~
6. ~~Hide exercise animation stub; gate `HapticManager` on `hapticsEnabled`~~
7. ~~Retarget `AGENTS.md`; remove dead onboarding from target if unused~~
8. ~~Verify `xcodebuild` (device or generic sim)~~

## Files
- `SettingsView.swift`, `WorkoutTrackerApp.swift`, `ContentView.swift`
- `ThemeManager.swift`, `DesignerComponents.swift` (HapticManager)
- `ProgressView.swift`, promo/profile leftovers
- `ExerciseVideoView.swift`, `Localizable.xcstrings`, `AGENTS.md`
- New: `AppearanceModeTests.swift`, extend haptic tests if needed

## Continuations

| Pass | Doc |
|------|-----|
| Full audit | `docs/audits/2026-11-01-full-report.md` |
| Improve | `docs/superpowers/plans/2026-11-01-improve-pass.md` |
| Residual | `docs/audits/2026-11-01-residual-fix-status.md` |
