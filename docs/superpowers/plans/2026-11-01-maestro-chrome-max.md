# Maestro Chrome-max Implementation Plan

> **For agentic workers:** Execute task-by-task. Prefer EN catalog + `wt.*` ids.

**Goal:** Phase 3 chrome Maestro suite green + fix Settings reachability and fake streak.

## Tasks
1. Fix Overview Settings gear + Hub streak honesty
2. UITestMode: consent AI; add `wt.*` ids
3. Add flows: settings, profile, calendar, progress empty, aihub, create, explore, add-exercise sheet
4. `./scripts/maestro_run.sh smoke` + `workout` green
5. Commit when asked

## Verify
```bash
./scripts/maestro_run.sh smoke
./scripts/maestro_run.sh workout
```
