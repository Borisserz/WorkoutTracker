# Plan: Colleague merge + hardening (2026-11-01)

## Goal

Integrate `origin/develop` `50bb2a5` into `fix/post-redesign-audit`, keep ADR + Maestro, fix honesty/l10n/memory, extend Maestro, verify.

## Tasks

1. Merge `origin/develop`; hand-resolve Hub / SmartBuilder / AICoach / AppState / HapticManager / Progress.
2. P0 honesty: real week bar; no invented recovery muscles; keep CNS `-1`; returned workout id.
3. Design: drop ALL-CAPS «В ОГНЕ» / decorative dots; gate haptics; restore streak or split CTA.
4. Memory: History `@Query` window/`fetchLimit`; audit sync wipe paths.
5. Localization: EN catalog keys + ru for new strings.
6. Maestro: calendar sheet, smart builder, progress; run `./scripts/maestro_run.sh all`.
7. `xcodebuild` build + `WorkoutTrackerTests`.
8. Write deep analysis audit doc.

## Done when

- Build + unit tests green
- Maestro all green (or failures documented + fixed)
- No invented week/CNS/recovery copy
- Colleague UX kept where it doesn’t violate ADR/Pastel
