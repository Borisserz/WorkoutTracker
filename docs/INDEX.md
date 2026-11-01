# WorkoutTracker documentation index

Last updated: **2026-11-01** (post-redesign audit + residual fix pass)

## Agent entry points

| Doc | Purpose |
|-----|---------|
| [`AGENTS.md`](../AGENTS.md) | Hard rules, design system, verification |
| [`README.md`](../README.md) | Public product overview + local build |

## Audits (2026-11-01)

| Doc | Status |
|-----|--------|
| [`audits/2026-11-01-inventory.md`](audits/2026-11-01-inventory.md) | File inventory for audit |
| [`audits/2026-11-01-full-report.md`](audits/2026-11-01-full-report.md) | Breaks B01–B28 + Improve I01–I20 (**closed**) |
| [`audits/2026-11-01-residual-report.md`](audits/2026-11-01-residual-report.md) | Residual R01–R14 + J01–J16 findings |
| [`audits/2026-11-01-residual-fix-status.md`](audits/2026-11-01-residual-fix-status.md) | Residual fix checklist (**closed**) |
| [`audits/2026-11-01-polish-pass.md`](audits/2026-11-01-polish-pass.md) | Post-residual P0/P1 polish (**closed**) |
| [`audits/2026-11-01-ideal-pass.md`](audits/2026-11-01-ideal-pass.md) | Final ideal pass + full test proof (**closed**) |
| [`audits/2026-11-01-full-verification.md`](audits/2026-11-01-full-verification.md) | Full-app retest: build + 46 tests + sim smoke (**pass**) |
| [`audits/2026-11-01-prod-readiness.md`](audits/2026-11-01-prod-readiness.md) | Prod/App Store readiness + fixes this pass |
| [`audits/2026-11-01-deep-app-analysis.md`](audits/2026-11-01-deep-app-analysis.md) | Post–colleague-merge deep feature/memory/l10n analysis |
| [`audits/2026-11-01-visual-pass.md`](audits/2026-11-01-visual-pass.md) | Pastel visual / anti-slop pass |
| [`audits/2026-11-01-agent-questions.md`](audits/2026-11-01-agent-questions.md) | Autonomous decisions / optional follow-ups |

## Maestro E2E (pending approval)

| Doc | Status |
|-----|--------|
| [`superpowers/specs/2026-11-01-maestro-e2e-design.md`](superpowers/specs/2026-11-01-maestro-e2e-design.md) | Design — **awaiting your «ок»** |
| [`superpowers/plans/2026-11-01-maestro-e2e.md`](superpowers/plans/2026-11-01-maestro-e2e.md) | Implementation plan (Phase 1 smoke) |

## Plans

| Doc | Status |
|-----|--------|
| [`superpowers/plans/2026-11-01-full-app-audit.md`](superpowers/plans/2026-11-01-full-app-audit.md) | Audit plan |
| [`superpowers/plans/2026-11-01-post-redesign-audit-fixes.md`](superpowers/plans/2026-11-01-post-redesign-audit-fixes.md) | Breaks fix plan |
| [`superpowers/plans/2026-11-01-improve-pass.md`](superpowers/plans/2026-11-01-improve-pass.md) | Improve I01–I20 (**done**) |
| [`superpowers/plans/2026-11-01-residual-audit.md`](superpowers/plans/2026-11-01-residual-audit.md) | Residual audit + fix (**done**) |

## Architecture decisions

| Doc | Decision |
|-----|----------|
| [`adr/0001-session-safety-cns-signout.md`](adr/0001-session-safety-cns-signout.md) | Single active session; honest CNS; CloudKit-safe sign-out |

## Current branch context

- Working branch for this pass: `fix/post-redesign-audit`
- Default remote branch: `develop`
- Do **not** commit/push unless the user asks («коммит» / PR)
