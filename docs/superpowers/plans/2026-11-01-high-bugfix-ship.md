# High bugfix → ship develop

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close High findings from feature audit, verify with tests, push to `develop` (remote default; no `main`).

**Architecture:** Keep session/stats mutations in `WorkoutStore` / `WorkoutService`. Honesty defaults stay empty/`nil`/`—`, never invent `100`. Offline Legendary fallback must match claimed equipment.

**Tech Stack:** SwiftUI, SwiftData, XCTest, xcodebuild

---

### Task 1: deleteWorkout stats honesty

**Files:**
- Modify: `WorkoutTracker/DataLayer/Repositories/WorkoutStore.swift`
- Test: `WorkoutTrackerTests/ResidualPassTests.swift` (or new focused tests)

- [ ] Write failing test: unfinished workout delete must not change `UserStats.totalWorkouts`
- [ ] Write failing test: finished (processed) workout delete may decrement
- [ ] Implement: only reverse stats when `endTime != nil` (was counted)
- [ ] Run tests green

### Task 2: Dual-session lock + finish-undo hole

**Files:**
- Modify: `WorkoutTracker/Services/Domain/WorkoutService.swift`
- Modify: finish path in WorkoutDetailViewModel if undo clears endTime while allowing new start
- Test: ResidualPassTests concurrent + undo race if feasible

- [ ] Confirm `startInFlight` set BEFORE `hasActiveWorkout`
- [ ] Close finish-undo dual-active window (keep guard until commit/undo settles, or refuse start while pending finish)
- [ ] Tests green

### Task 3: Legendary offline fallback honesty

**Files:**
- Modify: `WorkoutTracker/Features/Workout/Views/WorkoutHubView.swift` (`fallbackLegendaryRoutines`)

- [ ] XERO / bodyweight cards: bodyweight-only exercises, no barbell+kg mismatch
- [ ] Manual/logic check in test or static assertion if easy

### Task 4: Heatmap + generation honesty

**Files:**
- Modify: `WorkoutTracker/SharedUI/Components/BodyHeatmapView.swift`
- Modify: `WorkoutTracker/Services/Domain/WorkoutGenerationService.swift`
- Test: honesty unit tests

- [ ] Missing slug → omit / treat as unmeasured, not `?? 100`
- [ ] Empty recoveryStatus → `generateProactiveProposal` returns nil
- [ ] Tests green

### Task 5: Verify + ship

- [ ] `xcodebuild` test WorkoutTrackerTests
- [ ] Commit (user requested ship)
- [ ] Push `develop` (not `main` — does not exist on remote)
