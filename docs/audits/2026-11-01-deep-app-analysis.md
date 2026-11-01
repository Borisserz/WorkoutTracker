# Deep app analysis — 2026-11-01 (post colleague merge)

Branch: `fix/post-redesign-audit` (merged `origin/develop` `50bb2a5`)

## Verdict

**Core product is solid (~8.5/10).** ADR honesty + single-session + Maestro deep loop hold after integrating colleague UI. Remaining gaps are ship ops, device/Watch, History paging beyond 400, Progress Comparison removal, and leftover RU hardcodes outside this pass.

## Colleague commit `50bb2a5` (moggerrescure)

| Intent | Disposition |
|--------|-------------|
| Calendar CTA from Hub week bar | Kept — real week data + EN + `wt.hub.weeklyActivity` |
| Smart Builder recovery redesign | Kept chrome — **removed invented muscles**; honest empty states |
| AI settings Pastel sheet + deep links | Kept — EN catalog keys |
| Fiery Legendary + «В ОГНЕ» | Tonеd down; EN “Featured”; no ALL-CAPS / dots |
| Progress drop Comparison | Kept (product choice from develop) |
| Fake hardcoded week ПН…ВС | **Rejected** — replaced with real `weeklyConsistencyDays` |

## Feature / screen matrix

| Screen | Works? | Notes / follow-ups |
|--------|--------|--------------------|
| Overview | Yes | CNS honesty; Settings gear; calendar |
| Hub | Yes | Streak popup restored; week→calendar; legendary |
| Discovery / empty start | Yes | Maestro |
| Smart Builder | Yes | Recovery honesty; custom builder |
| Active workout / log set / finish | Yes | Deep Maestro |
| History | Yes | `@Query` fetchLimit **400** |
| Progress | Yes | Comparison section removed by colleague |
| AI Hub | Yes | Readiness card kept; coach dialog |
| Profile / Settings | Yes | Sign-out ≠ wipe verified |
| Explore / Legendary | Partial | UI entry OK; content = Firestore |
| Watch / Widget | Code OK | Device smoke still required |
| Auth / FatSecret | Ops | Rotate secrets; Archive production push |

## Memory / sync

- History capped at 400 newest workouts (RAM).
- Hub week scan uses `finishedWorkouts.prefix(90)` (Query still unbounded — next harden).
- CloudKit: sim off; device private DB; sign-out does not `deleteLocalData()`.
- Wipe only Delete Account / Delete Profile / DEBUG Clear All.
- **Recovery honesty fix:** `AnalyticsService.calculateRecovery` returns `[]` when no fatigue history (was inventing 100% for every muscle slug).

## Localization

- New Hub / Smart Builder / AI settings strings → EN keys + `ru` in `Localizable.xcstrings`.
- Residual: older screens may still mix RU hardcodes; date eyebrow now autoupdating locale.
- Catalog symbol clash avoided (`Ready to Train`).

## Test evidence (this pass)

- `xcodebuild` Debug **BUILD SUCCEEDED**
- `WorkoutTrackerTests` **TEST SUCCEEDED**
- Maestro: see runner log after `./scripts/maestro_run.sh all` (19 flows)

## Prioritized follow-ups

1. **P0 ship:** FatSecret rotate (R-02); Archive `aps-environment=production` (R-01); device+Watch smoke (R-05).
2. **P1:** Hub/Progress `@Query` fetchLimit; restore Comparison behind flag or drop dead code; dual-start unit race test.
3. **P2:** Maestro awards/catalog; WatchConnectivity flow; gate remaining ungated `print`s; full RU sweep of Explore/Firestore copy.
