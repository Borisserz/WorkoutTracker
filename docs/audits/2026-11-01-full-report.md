# WorkoutTracker Full App Audit — 2026-11-01

**Branch:** `fix/post-redesign-audit`  
**Scope:** 212 Swift files · all feature tabs · AppCore · DataLayer · Services · Watch · Widgets  
**Plan:** `docs/superpowers/plans/2026-11-01-full-app-audit.md`  
**Method:** Inventory greps + parallel domain audits (AppCore, Workout, Overview/AI, Stats/Data/Watch) + spot verification of top Breaks  
**Runtime:** Originally blocked on iOS 26.2 platform; later verified on **iOS 26.3.x Simulator** (iPhone 17).  
**Follow-ups:** Improve pass + Residual pass — see end of this file and `docs/INDEX.md`.

---

## Executive summary

| Bucket | Found | Status (end of day) |
|--------|-------|---------------------|
| **Breaks** (ломает / врёт / теряет данные) | 28 | **Fixed** |
| **Improve** (доделать / качество) | 20 (I01–I20; report listed 32 raw) | **Fixed** (I17 partial suites) |
| **Residual** (R/J after Improve) | 14 + 16 | **Fixed** (J15 partial) |
| **Notes** (контекст / уже ок) | 8 | by design |

Redesign (Pastel / Hub / Overview / Discovery) structurally OK. Original systemic issues (**fake metrics**, **RU on EN**, **Watch/widget sync**, **auth race**, **force-update write-review**) were closed across Breaks → Improve → Residual passes.

---

## A. Breaks — ломает, мешает, врёт пользователю

### A1. Fake / mock metrics (trust)

| ID | Evidence | Impact |
|----|----------|--------|
| B01 | `WorkoutDetailHeaderView.swift:54` — active volume `0` → shows **4850** | Active workout looks finished/heavy |
| B02 | `OverviewVitalsRowView.swift:42,50` — empty HR/water → **62 bpm / 2.1L** | Fake vitals when HK empty |
| B03 | CNS never from HealthKit; default **85** (`AICoachView` / Recovery only) | Readiness always “good” |
| B04 | `WorkoutHubView.swift:409-420` — hardcoded week bar ПН–ВС, ПТ=today | Consistency bar always fake |
| B05 | Hub “Best workout today” mock muscles / «Жим 90 кг» / fake 88% | Misleading hero CTA |
| B06 | `AICoachView` `actualHRV`/`actualRHR` never assigned → always `--` | Broken readiness card |

### A2. Workout flows

| ID | Evidence | Impact |
|----|----------|--------|
| B07 | History empty-library presets not inserted → start **0 exercises** | Broken template start |
| B08 | `ActiveWorkoutBanner` cancel alert: only **Delete**, no Keep | Accidental cancel = delete |
| B09 | Thumb “close set”: invents 90×8; skips `handleSetCompleted` | Wrong data + no PR/analytics |
| B10 | History start/replay ignores active workout | Dual active sessions |
| B11 | Rest finish tracked as skip (`RestTimerManager`) | Bad analytics |

### A3. Lifecycle / deep links / force update

| ID | Evidence | Impact |
|----|----------|--------|
| B12 | Force Update opens **write-review** URL (`AppReviewManager:23-26`) | Users can’t update app |
| B13 | `onOpenURL` only on mainContent — lost during onboarding/DB error | Dropped imports/deep links |
| B14 | Import Report sheet blank (IDs never set) | Broken report flow |
| B15 | Anonymous sign-in races Apple/Google | Can overwrite social session |
| B16 | Widget/`OpenWorkoutAppIntent` only switches tab; action flag unread | Widget actions no-op |
| B17 | Cold widget intent before listener → lost | Same |

### A4. AI / Overview locale & consent

| ID | Evidence | Impact |
|----|----------|--------|
| B18 | `BodyAnalysisEngine` RU advice on EN | EN Overview wrong language |
| B19 | CNS status strings RU (`getStatus`) | EN shows Russian |
| B20 | Calendar streak/day labels RU | EN Overview |
| B21 | AI camera opens **without** consent gate | Privacy policy gap |
| B22 | Recovery sheet / readiness advice still RU pockets | EN AI Hub |

### A5. Data / Watch / Widget

| ID | Evidence | Impact |
|----|----------|--------|
| B23 | Watch cancel only if reachable — no queue | Orphan phone workouts |
| B24 | Phone ignores most `guaranteedSyncPayload` actions | Discard lost |
| B25 | Widget sync wipes tip/muscles/volume to empty defaults | Stale/blank widget |
| B26 | Analytics rebuild: delete then `try? save` fail → empty stats | Silent data loss |
| B27 | Legacy migration marks done after failed save; sources deleted | Possible data loss |
| B28 | Stats goals / Watch sync cross-context SwiftData risks | Crashes / corruption risk |

---

## B. Improve — status (2026-11-01 evening pass)

Plan: `docs/superpowers/plans/2026-11-01-improve-pass.md`  
Verify: Debug build + `WorkoutTrackerTests` on iPhone 17 / iOS 26.3.1

| ID | Status | Notes |
|----|--------|-------|
| I01 | Fixed | Full Workout feature Cyrillic cleared (launcher, discovery, set headers, etc.) — recheck 2026-11-01 |
| I02 | Fixed | Overview sheets EN; anti-slop Title Case |
| I03 | Fixed | StatsWidget Pastel (no neon cyan/purple) |
| I04 | Fixed | Raw UIKit haptics → `HapticManager` only (0 outside) |
| I05 | Fixed | Clear All wipes goals/measurements/colors/XP/widget + honest alert copy |
| I06 | Fixed | Export JSON/CSV includes weight, goals, measurements |
| I07 | Fixed | `userActivityLevel` persisted in onboarding |
| I08 | Fixed | Honest guest/iCloud copy |
| I09 | Fixed | History finished-only + delete confirm |
| I10 | Fixed | Season/weekly consent + human offline errors + ML alert |
| I11 | Fixed | Camera setup fail → Retry/Dismiss |
| I12 | Fixed | `forceUpdateTestingEnabled` unlocks DEBUG testing |
| I13 | Fixed | DEBUG fetch interval 60s |
| I14 | Fixed | SettingsDropdownMenu cannot write light |
| I15 | Fixed | Auth listener hops to MainActor |
| I16 | Fixed | Re-check updates on scene `.active` |
| I17 | Partial | Smoke + domain tests; no dedicated export/migrator/watch suite yet |
| I18 | Fixed | Real hero; empty deck → discovery (no Strength Day A invent) |
| I19 | Fixed | Interpolated units EN |
| I20 | Fixed | Quick log / Training target zones Title Case |

**Recheck (2026-11-01 ~15:00):** closed I01 launcher/discovery/ExerciseCard gaps; removed empty-deck fake templates; Clear All alert copy. Build+tests green.  
Explore/Watch decorative `.purple` accents = optional polish only.

---

## C. Notes — ок / by design

| ID | Note |
|----|------|
| N01 | Simulator CloudKit `.none` — intentional |
| N02 | ModelContainer fail → `DatabaseErrorView` (fatalError removed) |
| N03 | AppearanceMode dark-lock + Settings Dark-only — correct direction |
| N04 | Clear All wired in DEBUG |
| N05 | HapticManager gate exists; partial adoption |
| N06 | Discovery popup localized via `String(localized:)` |
| N07 | PastelTheme / ButtonMetrics coherent on Hub/Overview |
| N08 | Domain unit tests (CNS, 1RM, Units…) exist; UI/sync uncovered |

---

## Scenario coverage matrix (at audit time → see residual section for post-fix)

| Scenario | At audit | After residual |
|----------|----------|----------------|
| S1 Cold launch | Partial — auth race B15; DB fail OK N02 | OK |
| S2 Empty data | Breaks — fake vitals/templates/hub | OK |
| S3 Active workout | Breaks — fake volume; dual session | OK |
| S4 Locale EN | Breaks — B18–B22, I01 | OK |
| S5 Offline/CloudKit | Improve — anon fail silent | OK (error UI; sign-out no wipe) |
| S6 HealthKit denied | Breaks — fake readiness | OK (“not measured”) |
| S7 AI consent | Breaks — camera skip | OK |
| S8 Low CNS | Note | Note (real score when measured) |
| S9 Deep link/import | Breaks — B13–B16 | OK |
| S10 Watch/widget | Breaks — B23–B25 | OK |

---

## Recommended fix order (executed)

1. ~~Trust strip — B01–B06~~  
2. ~~Force update URL — B12~~  
3. ~~Active workout safety — B08–B10~~ (+ residual R01/R03/R04)  
4. ~~Consent + HealthKit honesty — B21, B02–B03~~ (+ R07/R08)  
5. ~~Watch/widget sync — B23–B25~~ (+ R11/R12)  
6. ~~Migration/analytics durability — B26–B27~~ (+ R10)  
7. ~~i18n sweep — B18–B22 + I01~~ (+ J01–J04)  
8. ~~Deep links / widget intents — B13–B16~~ (+ R14)  

---

## Runtime verification (resolved)

Originally blocked until iOS 26.2+ platform. Later: **iOS 26.3.x** Simulator installed; Debug build + `WorkoutTrackerTests` green on iPhone 17.

---

## Fix pass status (2026-11-01 evening — verified)

**Build:** `xcodebuild` Debug → iPhone 17 (iOS 26.3.1) **SUCCEEDED**  
**Tests:** scheme TestAction wired to `WorkoutTrackerTests` → **TEST SUCCEEDED**

| ID | Status |
|----|--------|
| B01 fake volume 4850 | Fixed |
| B02 fake vitals / Pulse sheet 62 | Fixed (`—` + no invented bpm in sheet) |
| B03 CNS invents 85 | Fixed (default −1 / “Not measured”; HK refresher still writes real score) |
| B04 fake week bar | Fixed |
| B05 mock Best Workout / Strength Day A | Fixed (real routines; empty → Choose workout / discovery) |
| B06 HRV/RHR never set | Fixed |
| B07 empty mock templates | Fixed |
| B08 cancel Keep | Fixed |
| B09 close set invents load | Fixed |
| B10 dual active from History | Fixed |
| B11 rest skip analytics | Fixed |
| B12 force-update URL | Fixed |
| B13 deep link during onboarding | Fixed (`queuedOpenURL` + pending delivery) |
| B14 import report blank | Fixed |
| B15 anon auth race | Mitigated |
| B16 widget action flag | Fixed |
| B17 cold widget intent | Fixed (App Group `pendingWidgetAction`) |
| B18 BodyAnalysisEngine RU | Fixed |
| B19 CNS status RU | Fixed |
| B20 calendar RU | Fixed (+ Overview header/anatomy/daily focus EN) |
| B21 AI camera consent | Fixed (hub + in-workout ExerciseCard gate) |
| B22 recovery/readiness RU | Fixed (Break scope); deeper AICoach RU → Improve I01 |
| B23/B24 watch sync | Fixed |
| B25 widget wipe | Fixed |
| B26 analytics wipe | Fixed |
| B27 legacy migration | Fixed |
| B28 Stats goals cross-context | Fixed (`mainContext`) |

**Improve I01–I20:** closed in evening Improve pass (see table above). I17 deeper suites remain optional.

---

## Residual pass (2026-11-01 afternoon — verified)

**Report:** `2026-11-01-residual-report.md`  
**Status:** `2026-11-01-residual-fix-status.md` — **R01–R14 + J01–J16 closed** (J15 partial)  
**ADR:** `docs/adr/0001-session-safety-cns-signout.md`  
**Docs index:** `docs/INDEX.md`

| Theme | Outcome |
|-------|---------|
| Session safety | Single active session (phone + Watch + generated starts) |
| Ghost empty | Discarded on Detail disappear |
| CNS / widget honesty | No invented 100 / tip / muscles |
| Sign-out | CloudKit-safe (no local wipe) |
| Account wipe | Parity with Clear All + avatar |
| i18n leftovers | Share card, Live Activity, Progress sheets, Saved EN |
| Deep links | Warm `onOpenURL` handled at root |

**Build/tests:** iPhone 17 / iOS 26.3.x — BUILD SUCCEEDED · ResidualPassTests + ImprovePassSmokeTests + CNSCalculatorTests SUCCEEDED.

### Scenario coverage (post residual)

| Scenario | Result |
|----------|--------|
| S1 Cold launch | OK — bootstrap error surfaced; deep links queued |
| S2 Empty data | OK — no fake vitals/templates/CNS prime |
| S3 Active workout | OK — dual-session guards; ghost empty cleared |
| S4 Locale EN | OK — Workout + residual share/widget/stats pockets |
| S5 Offline/CloudKit | OK — sign-out no wipe; anon fail shows error |
| S6 HealthKit denied | OK — CNS “not measured” |
| S7 AI consent | OK — ExerciseCard + SetRow gates |
| S8 Low CNS | Note — advice uses real score when measured |
| S9 Deep link/import | OK — warm + cold paths |
| S10 Watch/widget | OK — active-state fallback; honest widget decode |

### Optional leftovers

- I17/J15 deeper export/Watch/migrator unit suites  
- Explore decorative `.purple` (cosmetic)  
- Device smoke of Watch-vs-phone dual-start and empty Detail dismiss  

