# Maestro Phase 3 — Chrome-max coverage

**Approved:** approach 1 (chrome-max). Deep log-set deferred.

## In scope
Overview (profile, calendar, settings, body analysis), Hub (create, explore), Progress empty, AI Hub (settings sheet + Recovery, no mic), session Add Exercise sheet open/dismiss, History/CNS already covered.

## Out of scope (v1)
Watch, Widget, Live Activity, Sign-In, FatSecret, full set logging.

## Bugs found while mapping
1. Settings only wired via unused `onSettingsTap` — add gear on Overview header.
2. Hub `displayStreakCount` falls back to invented `14` — return real streak (0 ok).

## UITestMode extras
Set `hasConsentedToAI = true` so AI Hub chrome flows skip consent sheet.
