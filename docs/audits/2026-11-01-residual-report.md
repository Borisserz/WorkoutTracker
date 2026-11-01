# Residual Full-Code Audit — 2026-11-01 (post Breaks + Improve)

**Branch:** `fix/post-redesign-audit`  
**Scope:** Full Swift tree after Breaks B01–B28 and Improve I01–I20 passes  
**Method:** Parallel domain audits (AppCore/Auth/Settings · Workout · Overview/AI/Stats/Watch/Widgets) + global greps + spot verification of Critical/High  
**Prior reports:** `2026-11-01-full-report.md` (Breaks/Improve closed)  
**Fix status:** [`2026-11-01-residual-fix-status.md`](2026-11-01-residual-fix-status.md) — **all items Fixed** (J15 partial tests only)

---

## Executive summary

| Bucket | Found | Fixed |
|--------|-------|-------|
| **Breaks** | 14 | 14 |
| **Improve** | 16 | 15 Fixed + J15 Partial |
| **Notes** | 5 | n/a (by design) |

Prior passes closed the redesign trust strip, EN Hub/History/AI Coach UI, and most sync durability bugs. Residual pass closed **session safety**, **account/wipe honesty**, **CNS/widget honesty**, remaining **RU pockets**, and related UX/export polish.

---

## A. Breaks (original findings → Fixed)

| ID | Severity | Original impact | Resolution |
|----|----------|-----------------|------------|
| R01 | Critical | Dual active from Watch | Guard before insert; surface existing session |
| R02 | Critical | Sign-out wipe → CloudKit deletes | Sign-out no longer wipes SwiftData |
| R03 | High | Legendary/AI dual session | Central guard in `startGeneratedWorkout` |
| R04 | High | Ghost empty active | Delete empty on Detail disappear |
| R05 | High | Replay lost sets | Hub-style `Exercise(from: toDTO())` |
| R06 | High | Blocked list race | One-shot hydrate + restart after sign-out |
| R07 | High | CNS unknown → 100 | Pass-through; engine “not measured” |
| R08 | Medium | Invented HRV/RHR points | `-1` if both missing; else 0 for missing component |
| R09 | Medium | Fake +1h stale finish | Delete empty; else real elapsed |
| R10 | Medium | Cross-context analytics models | Main-context fetch |
| R11 | Medium | Watch sync holes | `transferUserInfo` fallback + save logging |
| R12 | Medium | Widget fake tip/muscles | Empty defaults |
| R13 | Medium | Incomplete account wipe | Clear All parity + avatar |
| R14 | Medium | Warm deep-link drop | Root `onOpenURL` handles when ready |

---

## B. Improve (original → Fixed)

| ID | Area | Resolution |
|----|------|------------|
| J01–J04 | i18n | Share card, Live Activity, Progress sheets, Saved, `formattedDetails` → EN |
| J05 | Theme | StatsWidget `accentGradient`, less glow, no ALL-CAPS |
| J06–J07 | Analytics/UX | Real start counts; return ID; ProgramDiscovery navigates |
| J08–J09 | UX | Rest uses `defaultRestTime`; Appearance dark-only section |
| J10–J11 | Data | Export presets/notes/chat/colors; streak full history |
| J12–J14 | Auth/AI | Google signOut; bootstrap error; AI save errors; SetRow consent |
| J15 | Tests | Residual + Improve smoke in target; deeper suites optional |
| J16 | Dead UI | Legacy WorkoutView honest empty + delete confirm |

---

## C. Notes (unchanged / by design)

| ID | Note |
|----|------|
| N01 | Features/Workout Cyrillic **0** after Improve recheck |
| N02 | Raw `UIImpactFeedbackGenerator` outside `HapticManager` — **0** |
| N03 | Account delete order (reauth → callable → Auth delete → wipe) intentional |
| N04 | Watch ModelContainer local-only; phone sync via WC |
| N05 | Calendar uses `PersistentIdentifier` correctly for navigation |

---

## Suggested fix order (executed)

1. ~~R01 + R03~~  
2. ~~R04~~  
3. ~~R07 + R08 + R12~~  
4. ~~R02 + R13 + R06~~  
5. ~~R05 + R09~~  
6. ~~J01–J04~~ (+ remaining J/R)

---

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
  -only-testing:WorkoutTrackerTests/ImprovePassSmokeTests \
  -only-testing:WorkoutTrackerTests/CNSCalculatorTests
```

**Evidence (2026-11-01):** BUILD SUCCEEDED · TEST SUCCEEDED (Residual 5 + Improve smoke 3 + CNS).
