# WorkoutTracker documentation index

Last updated: **2026-11-03** (readiness verify + Maestro harden)

## Agent entry points

| Doc | Purpose |
|-----|---------|
| [`AGENTS.md`](../AGENTS.md) | Hard rules, design system, verification |
| [`README.md`](../README.md) | Public product overview + local build |

## Audits (2026-11-03)

| Doc | Status |
|-----|--------|
| [`audits/2026-11-03-full-audit.md`](audits/2026-11-03-full-audit.md) | Full-app audit + P1 fixes (**closed**, tests green) |
| [`audits/2026-11-03-p1-honesty-fix.md`](audits/2026-11-03-p1-honesty-fix.md) | Residual P1 honesty/UX pass (**closed**, tests green) |
| [`audits/2026-11-03-p2-polish-fix.md`](audits/2026-11-03-p2-polish-fix.md) | Residual P2 polish pass (**closed**, tests green) |
| [`audits/2026-11-03-p1-product-fix.md`](audits/2026-11-03-p1-product-fix.md) | Product P1 (brands / Watch HK / gesture / queries) (**closed**, tests green) |
| [`audits/2026-11-03-p2-anti-slop-pass.md`](audits/2026-11-03-p2-anti-slop-pass.md) | P2 anti-slop + dead Comparison UI (**closed**, tests green) |
| [`audits/2026-11-03-readiness-hardening.md`](audits/2026-11-03-readiness-hardening.md) | Readiness verify + Maestro smoke/workout (**conditionally ready**) |
| [`superpowers/specs/2026-11-03-readiness-hardening-design.md`](superpowers/specs/2026-11-03-readiness-hardening-design.md) | Design (approved) |
| [`superpowers/plans/2026-11-03-readiness-hardening.md`](superpowers/plans/2026-11-03-readiness-hardening.md) | Implementation plan |

## Audits (2026-11-02)

| Doc | Status |
|-----|--------|
| [`audits/2026-11-02-ideal-fix-pass.md`](audits/2026-11-02-ideal-fix-pass.md) | Ideal P0–P2 fix pass (**closed**, tests green) |
| [`audits/2026-11-02-watch-device-smoke.md`](audits/2026-11-02-watch-device-smoke.md) | Hardware smoke checklist (~15 min) for Watch + Live Activity |
| [`superpowers/specs/2026-11-02-sister-apps-promo-design.md`](superpowers/specs/2026-11-02-sister-apps-promo-design.md) | Sister apps Profile + one-time promo (**shipped**) |
| [`superpowers/plans/2026-11-02-sister-apps-promo.md`](superpowers/plans/2026-11-02-sister-apps-promo.md) | Implementation plan |

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

## Maestro E2E

| Doc | Status |
|-----|--------|
| [`superpowers/specs/2026-11-01-maestro-e2e-design.md`](superpowers/specs/2026-11-01-maestro-e2e-design.md) | Design — **implemented** |
| [`superpowers/plans/2026-11-01-maestro-e2e.md`](superpowers/plans/2026-11-01-maestro-e2e.md) | Phase 1+ flows in `.maestro/` |
| Re-run | `./scripts/maestro_run.sh smoke` · `workout` · `all` |

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
