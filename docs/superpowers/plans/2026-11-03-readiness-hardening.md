# Readiness verify + harden — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove unit + Maestro regression green, expand Maestro only for critical gaps, publish an honest readiness verdict + human ops checklist.

**Architecture:** No product features. Verify with `xcodebuild` + existing Maestro harness; fix only smoke/workout blockers; conditional session harden if dual-active hole appears; write `docs/audits/2026-11-03-readiness-hardening.md`.

**Tech Stack:** Xcode / iOS Simulator, XCTest (`WorkoutTrackerTests`), Maestro CLI, `scripts/maestro_run.sh`

## Global Constraints

- Spec: `docs/superpowers/specs/2026-11-03-readiness-hardening-design.md`
- No OpenRouter / Logger mass rewrite / Watch Maestro
- No git commit/push unless user asks «коммит»
- Verdict stays **Conditionally ready** while FatSecret rotate / Archive push / device smoke unchecked
- Prefer EN String Catalog; haptics via `HapticManager`; single active workout ADR

---

### Task 1: Unit test gate

**Files:**
- Verify only (no edits unless tests fail for environmental reasons)
- Report: later audit doc

- [x] **Step 1:** Boot/check Simulator; run:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test -only-testing:WorkoutTrackerTests
```

- [x] **Step 2:** On destination failure, retry `generic/platform=iOS` build or available sim name; record exact command used
- [x] **Step 3:** Capture pass/fail for the audit (`TEST SUCCEEDED` or first failure name)

---

### Task 2: Maestro smoke

**Files:**
- Run: `scripts/maestro_run.sh`
- Fix only if needed: `.maestro/flows/smoke_tabs.yaml`, a11y ids in tab/root views, `UITestLaunchConfiguration`

- [x] **Step 1:** `./scripts/maestro_run.sh smoke`
- [x] **Step 2:** If fail — note failing flow/assert; fix minimal (wait / id / UITestMode); re-run smoke once
- [x] **Step 3:** Record green or remaining blocker in audit notes

---

### Task 3: Maestro expand (critical paths)

**Files:**
- Existing: `.maestro/flows/workout_free_start.yaml`, `workout_log_set_finish.yaml`, `history_empty_state.yaml`, `settings_open.yaml`, …
- Create new YAML only if a critical path has **no** flow

- [x] **Step 1:** List tag coverage (`smoke` / `workout` / `deep` / …) vs critical paths: free start, log set→finish, History empty, Settings open
- [x] **Step 2:** Run `./scripts/maestro_run.sh workout` (or `deep` if that is the tag set for session loops)
- [x] **Step 3:** On gap or flake — add/fix flow for that path only; re-run the same tag
- [x] **Step 4:** Do **not** require `all` green for pass; note any skipped deep failures honestly

---

### Task 4: Session harden (conditional)

**Files:**
- Review: `WorkoutTracker/Services/Domain/WorkoutService.swift` (`startInFlight`, `finishTransitionDepth`)
- Test: `WorkoutTrackerTests/` residual / session tests if hole found

- [x] **Step 1:** Grep/review finish-undo + dual-start guards; check existing unit tests cover them
- [x] **Step 2:** If hole found — failing test → minimal fix → green
- [x] **Step 3:** If no hole — document “guards present, no code change”

---

### Task 5: Readiness audit + INDEX

**Files:**
- Create: `docs/audits/2026-11-03-readiness-hardening.md`
- Modify: `docs/INDEX.md` (add row under Audits 2026-11-03)

- [x] **Step 1:** Write audit with: verdict, unit evidence, Maestro evidence, session note, human ops checklist (R-01 FatSecret/Archive already covered in prod-readiness — link + checkbox list)
- [x] **Step 2:** Link Watch smoke doc + Maestro commands for re-run
- [x] **Step 3:** Update `docs/INDEX.md`
- [x] **Step 4:** Stop for user: offer «коммит» — do not commit unless asked

---

## Done when

- Unit tests succeeded (or blocked with exact env reason)
- Maestro smoke green (or blocked with exact fail)
- Workout/critical Maestro attempted; gaps filled or documented
- Audit + INDEX published with honest verdict
