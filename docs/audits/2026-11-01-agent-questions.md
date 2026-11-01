# Agent questions / blockers — 2026-11-01

Boris: you’re out. I’m deciding autonomously unless something here is blocking.

## Critical — cleared

1. ~~Xcode Platforms~~ — **iOS 26.3.1 Simulator installed.** Build + tests green on iPhone 17.
2. ~~Breaks B01–B28~~ — fixed + verified.
3. ~~Improve I01–I20~~ — fixed + verified (I17 deeper suites optional).
4. ~~Residual R01–R14 + J01–J16~~ — fixed + verified (J15 partial).

## Decisions I made without asking

- Closed remaining PARTIAL Breaks (B02 Pulse 62, B03 default 85→−1, B05 fake Strength Day A, B17 App Group widget stash, B21 in-workout camera consent, Overview EN leftovers).
- Deeper AICoach RU (settings / protocol builder) stayed **Improve I01**, not B22 — then cleared in Improve pass.
- Wired `WorkoutTrackerTests` into `WorkoutTracker.xcscheme` TestAction; later added `ResidualPassTests` + `ImprovePassSmokeTests` to the target.
- Residual: **sign-out does not wipe** SwiftData (CloudKit); CNS returns `-1` when vitals missing; single active-session API; empty Detail ghost delete.
- Documented in `docs/INDEX.md`, `docs/adr/0001-session-safety-cns-signout.md`, updated `AGENTS.md`.
- No git commit/push unless you ask.

## Optional when you’re back

1. Device smoke (~5 min): Hub start → leave empty Detail → no active banner; Overview CNS with HealthKit off → “Not measured”; Settings sign-out → data still there; Rest sheet before touching sliders → “—”.
2. Say «коммит» to commit audit + residual + polish + ideal passes on `fix/post-redesign-audit`.
3. Optional: WatchConnectivity unit suite only.
