# Ideal pass — 2026-11-01

**Branch:** `fix/post-redesign-audit`  
**Goal:** Close remaining post-polish leftovers; prove nothing regressed.  
**Index:** [`../INDEX.md`](../INDEX.md)

## Closed in this pass

| Area | Change |
|------|--------|
| Trust | Body Analysis preserves unknown readiness (`-1`); UI shows `—` |
| Trust | Rest fatigue ring shows “Not measured” until sleep/water adjusted |
| Saves | History replay + favorite swipe use `do/catch` + user errors |
| i18n | Profile achievements/filters/archive EN; Designer popup EN; SmartCapture EN |
| Pastel | Remaining `.purple` accents → lavender/amber/sage across Hub/Stats/Builder/Onboarding |
| Widget | `load()` fallback empty tip |
| Debug | MlVision prints English |
| Tests | Extra ResidualPass coverage (widget load, empty recovery) |

## Verification evidence

```text
xcodebuild … test -only-testing:WorkoutTrackerTests
** TEST SUCCEEDED **
```

Simulator: iPhone 17 / iOS 26.3.x

## Remaining non-blockers

- Muscle color picker still offers system `.purple` swatches (user choice palette — OK)
- Watch companion may keep its own accent tokens
- Physical-device smoke still recommended once
