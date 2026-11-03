# P2 anti-slop / dead-UI pass — 2026-11-03

Branch: `develop`

## Closed

| ID | Fix |
|----|-----|
| P2-dots | Removed decorative middle dots (` · `) from Hub/Calendar/Smart Builder/`formattedDetails` |
| P2-comparison | Deleted unused neon `ComparisonSectionView`; kept math in `PeriodComparisonMetrics` |
| P2-caps | Softened ALL-CAPS chrome (XP popup, Live badge, share receipt, promo Before/After, onboarding labels, Overview All) |

## Evidence

```text
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,id=E739C4E8-…' \
  -configuration Debug test -only-testing:WorkoutTrackerTests
** TEST SUCCEEDED **
```

Watch embed temporarily detached for the iOS test run (no `watchsimulator`), then `project.pbxproj` restored.

## Left as ops / out of scope

- FatSecret rotate, Archive push production, device+Watch smoke
- Installing `watchsimulator` runtime locally
