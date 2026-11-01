# Full App Audit Plan — WorkoutTracker

> **For agentic workers:** Execute tasks in parallel by domain. Record every finding with file:line evidence. Do not claim runtime verification without a successful build/launch.

**Goal:** Exhaustive correctness and quality audit of the entire iOS app (212 Swift files) after the Pastel redesign, with findings split into blockers, improvements, and notes.

**Architecture:** Native SwiftUI + SwiftData + Firebase + HealthKit + Watch/Widgets. Entry: `WorkoutTrackerApp` → DI → `ContentView` tabs (Overview, History, Workout Hub, AI Hub, Progress).

**Tech Stack:** SwiftUI, SwiftData/CloudKit, Firebase (Auth/Analytics/Crashlytics/RemoteConfig/Firestore), CoreML/Vision, WidgetKit, watchOS companion.

## Global Constraints

- Branch under review: `fix/post-redesign-audit` (includes redesign + audit fixes)
- Do not modify Firebase Console / other apps’ configs; code-only findings OK
- Build may be blocked until iOS 26.2 platform installs — static + scenario analysis still required
- PastelTheme is dark-only; CyberNeon must stay dead
- Evidence required: path + symbol/line; no speculative “might”

## Scenario Matrix (apply per feature)

| ID | Scenario |
|----|----------|
| S1 | Cold launch (guest / signed-in / DB fail) |
| S2 | Empty data (no workouts, no templates) |
| S3 | Active workout in progress + app background |
| S4 | Locale EN vs RU |
| S5 | Offline / CloudKit fail / simulator |
| S6 | HealthKit denied |
| S7 | AI consent denied / accepted |
| S8 | Low CNS / recovery edge |
| S9 | Import workout / deep link |
| S10 | Watch sync / widget / Live Activity |

---

### Task 1: Inventory & risk grep (orchestrator)

**Files:** Entire `WorkoutTracker/`

- [ ] Count files by module; list entry points
- [ ] Grep: `fatalError`, `force try`, `as!`, `!`, `TODO`, `FIXME`, empty `Button`, `UIImpactFeedbackGenerator`, `Color.purple`, hardcoded Cyrillic `Text("…")`, `systemGroupedBackground`
- [ ] Write baseline risk inventory to `docs/audits/2026-11-01-inventory.md`

### Task 2: AppCore / DI / lifecycle

**Files:** `AppCore/*`, `Auth/*`, `Features/Main/ContentView.swift`, `Features/Onboarding/*`

- [ ] Trace `setupDependencies` → ModelContainer → Environment injection
- [ ] Scenarios S1, S5, S9
- [ ] Theme/AppearanceMode honesty; force-update; onboarding paths

### Task 3: Workout Hub + Active Workout + History

**Files:** `Features/Workout/**`, rest timer, share card

- [ ] Start empty / AI / template discovery flows
- [ ] Active set logging, supersets, cancel/finish, timer overlay
- [ ] History edit/delete/share; empty states
- [ ] Scenarios S2, S3, S4, S8

### Task 4: Overview + Recovery + Calendar

**Files:** `Features/Overview/**`, HealthKit managers

- [ ] Anatomy readiness, daily focus, hydration/pulse sheets
- [ ] Calendar pressure plates / streaks
- [ ] Scenarios S6, S8, S4

### Task 5: AI Hub + SmartBuilder + Camera ML

**Files:** `Features/AICoach/**`, `Features/SmartBuilder/**`, `MlVision/**`, `Services/AI/**`

- [ ] Consent gate, chat, bento tools, weekly review
- [ ] AI camera exercise selector + classifier failure paths
- [ ] Scenarios S7, S5, S4

### Task 6: Progress / Profile / Settings / Promo

**Files:** `Features/Stats/**`, `Features/Profile/**`, `Features/Settings/**`, `Features/Promo/**`, `Features/Explore/**`, `Features/ExerciseCatalog/**`

- [ ] Stats share card, goals, PR
- [ ] Profile XP/achievements, FoodTracker promo
- [ ] Settings units/haptics/appearance/export/clear
- [ ] Catalog / Explore / legendary programs

### Task 7: DataLayer / Services / Watch / Widgets

**Files:** `DataLayer/**`, `Services/**`, `CoreLogic/**`, WatchApp, Widgets

- [ ] Repositories, migrations, analytics rebuild
- [ ] Phone↔Watch, widgets, Live Activities
- [ ] Remote Config / VersionManager DEBUG bypass

### Task 8: Synthesize report + canvas

- [ ] Merge findings into three buckets: **Breaks**, **Improve**, **Notes**
- [ ] Deduplicate; severity; suggested fix order
- [ ] Update canvas `full-app-audit.canvas.tsx` + `docs/audits/2026-11-01-full-report.md`

## Deliverable format per finding

```
[ID] SEV | Area | Title
Evidence: path:line
Scenario: S#
Impact: …
Fix: one concrete next step
```
