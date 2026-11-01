# Maestro E2E design — WorkoutTracker

**Date:** 2026-11-01  
**Status:** Ready for your review (approve → implement)  
**Branch context:** `fix/post-redesign-audit`  
**Default choice:** Smoke-first (option 1), then Core Workout, then wider suite

---

## 1. Goal

Replace fragile screenshot-only visual checks with **Maestro flows** that:

1. Launch the app on iOS Simulator in a deterministic “UI-test” state  
2. Assert main tabs and key screens without relying on pixel matching  
3. Grow into workout / history / AI Hub coverage without rewriting harness  

Success = `maestro test .maestro/` green on a booted iPhone 17 (or 17 Pro) Simulator after a Debug build install.

---

## 2. Why Maestro (vs XCUITest / screenshots)

| Approach | Pros | Cons |
|----------|------|------|
| **A. Maestro YAML + a11y ids (recommended)** | Fast to write, readable diffs, easy for agents, CI-friendly, optional screenshots as artifacts | Need stable `accessibilityIdentifier`s; system sheets need clear strategy |
| B. XCUITest only | Native Xcode, strong APIs | Heavier Swift test code, slower iteration for agents |
| C. Screenshot diffs only | Visual regression | Flaky (permissions, locale, Dynamic Island), no interaction proof |

**Recommendation:** A. Keep unit tests (`WorkoutTrackerTests`) for logic; Maestro for navigation + feature smoke; optional Maestro `takeScreenshot` on failure only.

---

## 3. Architecture

```
.maestro/
  config.yaml                 # appId, tags
  flows/
    smoke_tabs.yaml           # Phase 1
    workout_free_start.yaml   # Phase 2
  helpers/
    launch_uitest.yaml        # clearState + launch + dismiss system prompts
scripts/
  maestro_run.sh              # build → install → maestro test
WorkoutTracker/
  AppCore/UITestLaunchConfiguration.swift   # launch args → UserDefaults / skip sheets
  …views… .accessibilityIdentifier("…")
```

### App identity

- Bundle ID: `com.borisdev.WorkoutTracker`  
- Display name: `Ai Workout`  
- Scheme: `WorkoutTracker`  
- Prefer destination: `platform=iOS Simulator,name=iPhone 17` (fallback Pro)

### Deterministic launch (critical)

Cold launch today hits **HealthKit + Notifications** (and previously Speech). Maestro must not depend on clicking Apple system sheets every run.

**Launch argument:** `-UITestMode` (and optionally `-UITestSkipOnboarding`)

When present, app on startup:

1. Sets `hasCompletedGodModeOnboarding_v1 = true`  
2. Sets `hasSeenFeatureDiscovery = true`  
3. Skips / no-ops **notification** `requestAuthorization` and **HealthKit** `requestAuthorization` while in UITestMode (fetch returns empty/unknown; UI shows “—” / not measured — already honest)  
4. Does **not** wipe CloudKit prod data (UITestMode only changes prompts + onboarding flags)

This is the single most important design decision: **test the app UI, not Apple permission chrome.**

### Selectors

Prefer **accessibilityIdentifier** (stable), not localized text alone.

Proposed id convention: `wt.<area>.<control>`

| ID | Element |
|----|---------|
| `wt.tab.overview` | Tab bar Overview |
| `wt.tab.history` | Tab bar History |
| `wt.tab.workout` | Tab bar Workout |
| `wt.tab.aihub` | Tab bar AI Hub |
| `wt.tab.progress` | Tab bar Progress |
| `wt.hub.title` | Workout hub large title / root marker |
| `wt.hub.startWorkout` | Start workout CTA |
| `wt.overview.root` | Overview root |
| `wt.history.root` | History root |
| `wt.aihub.root` | AI Hub root |
| `wt.progress.root` | Progress root |

Tab items: apply identifiers via `UITabBarItem` / SwiftUI `.accessibilityIdentifier` on `.tabItem` where supported; if TabView ids are unreliable, assert **screen roots** after `tapOn: "Workout"` text as fallback Phase 1, then harden ids Phase 1.1.

---

## 4. Phased flows

### Phase 1 — Smoke (ship first)

`smoke_tabs.yaml`:

1. `launchApp` with `-UITestMode`  
2. Assert Workout hub visible (`wt.hub.title` or “Workout”)  
3. Tap each tab; assert matching root id / key EN string  
4. Optional: open Settings from Profile entry if easy — **out of Phase 1**

Tags: `smoke`

### Phase 2 — Core workout

`workout_free_start.yaml`:

1. Launch UITestMode  
2. Hub → Start workout → free/empty path  
3. Assert active workout UI  
4. Add one set / finish or cancel cleanly (single-session guards respected)  
5. History shows entry **or** empty→non-empty transition  

Tags: `workout`

### Phase 3 — Wider suite (later)

Separate flows: History filters, AI Hub open chat (no mic permission), Progress awards empty, Settings export button visible. No FatSecret / Watch / Live Activity in Maestro v1.

---

## 5. Tooling & CI

### Local

```bash
# Install once (macOS)
curl -Ls "https://get.maestro.mobile.dev" | bash

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./scripts/maestro_run.sh smoke   # build+install+maestro test --include-tags=smoke
```

### Script responsibilities

`scripts/maestro_run.sh`:

1. Resolve booted simulator or boot `iPhone 17`  
2. `xcodebuild` Debug → install `.app`  
3. `maestro test .maestro/flows --include-tags=…`  
4. Exit non-zero on fail; screenshots to `.maestro/output/` (gitignored)

### CI (optional follow-up)

GitHub Action on `macos-14` with Simulator — only after Phase 1 green locally. Not required for first merge.

---

## 6. Non-goals (v1)

- Watch / Widget / Live Activity E2E  
- Real HealthKit data assertions  
- Google/Apple Sign-In sheets  
- Pixel-perfect visual AI comparison  
- Replacing unit tests  

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| System permission sheets | UITestMode skips Health/Notifications auth prompts |
| Localized strings | Prefer a11y ids; EN catalog keys as secondary |
| TabView identifier quirks | Screen-root markers + text fallback |
| Flaky animations | `extendedWaitUntil` / Maestro `optional` for toasts |
| Dual active workout | Flows use cancel/finish; unit tests already guard service |

---

## 8. Approval checkpoint

When you return, reply **«ок» / «approve maestro»** to:

1. Accept this design (Smoke → Workout → Wider)  
2. Unlock implementation: UITestMode + a11y ids + `.maestro/` + `maestro_run.sh`  

Or say what to change (e.g. “don’t skip HealthKit”, “start with workout flow”).
