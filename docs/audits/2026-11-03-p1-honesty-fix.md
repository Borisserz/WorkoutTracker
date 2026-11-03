# P1 honesty / UX fix pass — 2026-11-03

Branch: `develop`  
Scope: All audit P1 findings from the residual + product UX review.

## Closed

| ID | Fix |
|----|-----|
| R-P1-01/02/03 | `RestFatigueEstimator` + Rest sheet no longer writes `cnsScore`; ring shows `—` until sleep measured; copy matches gate |
| R-P1-04 | Empty history → `overallReadiness = -1` (no invented 100% / peak copy) |
| R-P1-05 | Body analysis user-facing strings via `String(localized:)` |
| R-P1-06 | Removed fake AI Hub “Synced” toast; “Nutrition tip” → “Post-workout recovery tips” |
| Hub nav | “Explore programs” / templates CTA → `navigateToExplore` (not History tab) |
| Hub hero | Title honesty: “Your next routine” / “Suggested from recovery” |
| R-P1-07/08 | Watch HK start failure + local store failure surface alerts; store before phone sync |
| R-P1-09 | Overview streak catalog keys + RU |
| Guest | Softened overclaim copy |
| Progress share | Share sheet composes before/after image |
| Explore empty | Distinguishes server empty vs filter miss |

## Evidence

```text
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,id=E739C4E8-…' \
  -configuration Debug test -only-testing:WorkoutTrackerTests
** TEST SUCCEEDED **
```

Note: Watch embed dependency temporarily removed for the iOS test run (no `watchsimulator` runtime on this machine), then `project.pbxproj` restored.

## Ops still manual

1. Rotate FatSecret keys from git history.
2. Archive `aps-environment=production`.
3. Device + Watch smoke checklist.
