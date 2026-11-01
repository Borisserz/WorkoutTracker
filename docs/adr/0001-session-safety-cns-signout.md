# ADR-0001: Session safety, CNS honesty, CloudKit-safe sign-out

## Status

Accepted

## Date

2026-11-01

## Context

Post-redesign audits found trust bugs: dual active workouts (Watch / Legendary / AI), Overview inventing CNS **100** when unmeasured, widget decoder inventing muscles/tips, and sign-out wiping SwiftData while production uses CloudKit private DB (local deletes can sync to iCloud).

## Decision

1. **Single active session** — `WorkoutService.createWorkout` and `startGeneratedWorkout` refuse when `hasActiveWorkout()` is true; Watch `.startWorkout` resumes/points at the existing phone session instead of inserting a second one.
2. **CNS honesty** — `CNSCalculator` returns `-1` when both HRV and RHR are missing; missing components score **0** (not invented defaults). Overview/`BodyAnalysisEngine` treat `< 0` as “not measured”, never coerce to 100.
3. **Widget honesty** — `WidgetData` decoder defaults missing tip/muscles to empty, not marketing copy.
4. **Sign-out** — does **not** call `deleteLocalData()`. Restart `BlockedUsersStore` for the new anonymous uid. Full wipe stays on account deletion / explicit delete-profile / DEBUG Clear All (parity: XP, widget payload, muscle colors, avatar file).

## Alternatives considered

- Guard only in Hub UI — rejected: Legendary/AI/Watch bypass Hub.
- Soft-delete CloudKit zone on sign-out — rejected: too destructive for “sign out of Google/Apple”.
- Keep CNS sleep/water-only score when vitals missing — rejected: still reads as “healthy readiness”.

## Consequences

- Callers of `startGeneratedWorkout` should use the returned `PersistentIdentifier` (avoid `fetchLatestWorkout` races).
- Empty active Detail sessions are discarded on disappear to prevent ghost blockers.
- Agents must not reintroduce fake readiness numbers or wipe-on-sign-out.
