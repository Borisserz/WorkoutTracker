# Residual full-code audit + fix — 2026-11-01

**Goal:** After Breaks + Improve passes, find remaining Breaks / Improve / Notes across the whole app, then fix in order.

**Method:** Parallel domain greps + file reads; do not trust prior “Fixed” without spot-check.

**Buckets:** Breaks (lies/loss/crash/privacy) · Improve · Notes

## Outputs

| Artifact | Path | Status |
|----------|------|--------|
| Findings | `docs/audits/2026-11-01-residual-report.md` | Written |
| Fix checklist | `docs/audits/2026-11-01-residual-fix-status.md` | **CLOSED** |
| ADR | `docs/adr/0001-session-safety-cns-signout.md` | Accepted |
| Docs index | `docs/INDEX.md` | Updated |

## Fix order (executed)

1. R01 + R03 — active-session guard (Watch + generated starts)  
2. R04 — ghost empty on dismiss  
3. R07 + R08 + R12 — CNS / widget honesty  
4. R02 + R13 + R06 — wipe / sign-out / blocked list  
5. R05 + R09 — History replay + stale auto-finish  
6. R10–R14 + J01–J16 — analytics, Watch, deep links, i18n, export, tests  

## Verification

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test \
  -only-testing:WorkoutTrackerTests/ResidualPassTests \
  -only-testing:WorkoutTrackerTests/ImprovePassSmokeTests
```

**Result:** BUILD SUCCEEDED · TEST SUCCEEDED (2026-11-01).
