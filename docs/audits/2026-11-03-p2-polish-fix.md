# P2 polish fix pass — 2026-11-03

Branch: `develop` (+ merge to `main`)

## Closed

| ID | Fix |
|----|-----|
| R-P2-01 | `fetchLimit` on History favorites/presets, Profile, Progress weight cards, Library, AI chat history, Body measurements |
| R-P2-02 | Onboarding `.sensoryFeedback` gated by `HapticManager.areHapticsEnabled` |
| R-P2-03 | Removed dead `Cyber*` typealiases |
| R-P2-04/05 | Watch HK types already guarded; Camera preview no longer `as!` |
| R-P2-06/07 | `CalendarDateIntervals` helper; Progress/Analytics/Widget no force-unwrap intervals / month grid |
| R-P2-08 | MuscleMapping docs URL fallback |
| R-P2-09 | `LibraryFilter` stable ids + `localizedTitleKey` |
| R-P2-10 | Remote Config `lastFetchFailed` / error description |
| R-P2-12 | `WorkoutStore` uses local `end` Date |

## Evidence

`WorkoutTrackerTests` **TEST SUCCEEDED** on iPhone 17 (Watch embed temporarily detached for sim lacking `watchsimulator`, then restored).
