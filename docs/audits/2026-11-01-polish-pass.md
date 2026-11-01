# Polish pass — 2026-11-01 (post residual)

**Branch:** `fix/post-redesign-audit`  
**Trigger:** Current-state analysis after residual close; finish remaining trust / design / i18n gaps.  
**Index:** [`../INDEX.md`](../INDEX.md)

## Analysis summary

| Priority | Found | Action |
|----------|-------|--------|
| P0 trust | Fatigue sheet inventing shared CNS; empty recovery → fake 100%; silent Watch saves | Fixed |
| P1 design/i18n | System `.purple`/`.cyan`; RU discovery/profile/preset/builder; Explore offline looks live; RU prefix hack | Fixed |
| P2 quality | Widget gallery invents tip; Hub replay silent save; export test depth | Fixed (partial J15) |

## Fixes

| ID | Change |
|----|--------|
| P0-1 | `RestAnalysisSheet` no longer writes invented `cnsScore` to AppStorage |
| P0-2 | `BodyAnalysisEngine` skips inventing prime muscles when recovery map empty |
| P0-3 | Watch→phone `bgContext.save` failures surface via `appState.showError` |
| P1-1 | Feature discovery, profile XP, preset/builder copy → EN |
| P1-2 | Explore / Stats / EmptyState accents → Pastel lavender/sage/slate/amber |
| P1-3 | Program Discovery offline banner for bundled sample catalog |
| P1-4 | Removed Cyrillic prefix strip from daily focus |
| P2-1 | StatsWidget placeholder neutral (empty tip/muscles) |
| P2-2 | Hub favorite replay `do/catch` + user error |
| P2-3 | ResidualPassTests: empty recovery + export bundle keys |

## Verification

```text
BUILD SUCCEEDED
TEST SUCCEEDED — ResidualPassTests + ImprovePassSmokeTests + CNSCalculatorTests
```

## Follow-up

Closed in [`2026-11-01-ideal-pass.md`](2026-11-01-ideal-pass.md) (Profile/SmartCapture EN, Pastel accents, Rest “Not measured”, History saves, MlVision EN prints, full `WorkoutTrackerTests`).

## Still optional (not blockers)

- Dedicated WatchConnectivity unit suite
- Physical-device smoke once
