# Readiness verify + harden — Design

**Date:** 2026-11-03  
**Status:** Approved (approach 2 + optional Maestro expansion if gaps found)  
**Branch:** `develop` (or current working branch; no commit/push unless user asks)  
**Goal:** Confirm product readiness and strengthen regression coverage — **no new product features**.

## Context

Audits through 2026-11-03 closed code P0–P2. Prod readiness is **conditionally ready** for App Store; remaining blockers are mostly **ops** (FatSecret rotate, Archive `aps-environment`, device+Watch smoke). Maestro flows and `scripts/maestro_run.sh` already exist; session guards (`startInFlight`, `finishTransitionDepth`) are already in `WorkoutService`.

This pass is **verify + run existing moat + report**, not a greenfield Maestro build or Logger rewrite.

## Approach (approved)

**Verify + Maestro smoke** (½–1 day agent work + ~30–60 min human ops).

Rejected for this pass:

- Verify-only (too weak)
- Full moat (Logger mass replace, WatchConnectivity unit suite, Maestro deep-all) — defer

## Scope

### In scope

1. **Unit verify** — `xcodebuild … test -only-testing:WorkoutTrackerTests` on iPhone 17 Simulator (or documented fallback).
2. **Maestro** — `./scripts/maestro_run.sh smoke` first; fix blockers that prevent green. If smoke is green and critical paths lack coverage (free start → log set → finish, History empty, Settings open), **add/extend flows** for those paths only — still no Watch/Health/FatSecret system UI.
3. **Session harden (conditional)** — If tests/smoke/manual review show a dual-active or finish-undo hole, close it with a focused unit test. If guards already hold, **no code change**.
4. **Ops checklist (human)** — Copy actionable items into the readiness report: FatSecret rotate, Archive push entitlement, Watch+Live Activity device smoke (`docs/audits/2026-11-02-watch-device-smoke.md`), App Review notes. Agent does not rotate secrets or Archive on a personal Apple ID without user.
5. **Deliverable** — `docs/audits/2026-11-03-readiness-hardening.md` with verdict: **Ready** / **Conditionally ready** / **Blocked**, evidence (test + Maestro exit), and remaining human steps.

### Out of scope

- New features, OpenRouter migration, sister-apps changes
- Mass `print` → `os.Logger`
- Dedicated WatchConnectivity XCTest suite
- Full `maestro_run.sh all` as a hard gate; Watch / Live Activity / FatSecret system UI in Maestro
- Git commit/push unless user says «коммит»

## Architecture / flow

```
1. xcodebuild test (WorkoutTrackerTests)
2. maestro_run.sh smoke
3. If fail → fix minimal (test harness / a11y / flake) → re-run
4. If dual-session hole found → unit test + WorkoutService fix
5. Write readiness audit doc + update docs/INDEX.md row
6. Hand human ops checklist
```

Success criteria:

- Unit tests **TEST SUCCEEDED**
- Maestro **smoke** tag green once on a booted Simulator
- Readiness doc states honest verdict + ops leftovers (no fake “shipped” if FatSecret/Archive unchecked)

## Risks

| Risk | Mitigation |
|------|------------|
| Simulator / Maestro / Java missing | Document exact failure; do not claim smoke green |
| Smoke fails on permission sheets | Confirm `-UITestMode` path still skips Health/Notifications/onboarding |
| False “Ready” while ops open | Verdict stays **Conditionally ready** until human checks R-01/R-02/R-05 |

## Related docs

- `docs/audits/2026-11-01-prod-readiness.md` — ops R-01…R-07
- `docs/audits/2026-11-02-watch-device-smoke.md` — hardware checklist
- `docs/superpowers/specs/2026-11-01-maestro-e2e-design.md` — Maestro contract (already implemented)
- `AGENTS.md` — verification commands
