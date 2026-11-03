# P1 product fix pass — 2026-11-03

Branch: `develop`

## Closed

| ID | Fix |
|----|-----|
| P1-brand | Offline Legendary + Mock Explore + Hub chrome: no ATHLEAN / Arnold / Mentzer titles; AI persona defaults no longer impersonate celebrities |
| P1-watch-hk | `WatchWorkoutManager.didFailWithError` surfaces `WatchSessionPolicy.healthKitSessionFailureMessage` |
| P1-gesture | `GestureTuning.confidenceThreshold` raised `0.35` → `0.5` |
| P1-query | Hub + ActiveWorkoutBanner `activeWorkouts` `@Query` `fetchLimit = 5` |
| P1-dead | Removed unused Hub fake-weight template helpers (`defaultPowerDayA` / `templateCard`) |
| P1-explore | ProgramDiscovery uses `LegendaryFallbackCatalog`; sample banners say generic names only |

## Evidence

```text
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,id=E739C4E8-…' \
  -configuration Debug test -only-testing:WorkoutTrackerTests
** TEST SUCCEEDED **
```

Note: Watch embed temporarily detached for the iOS test run (no `watchsimulator` runtime), then `project.pbxproj` restored.

## Still manual (ops P0)

1. Rotate FatSecret keys from git history.
2. Archive `aps-environment=production`.
3. Device + Watch smoke checklist.
