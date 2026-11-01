# WorkoutTracker Agent Directives & Persistent Memory

> Applies to every session on this machine. Paths below are for Boris’s checkout.

## Workspace

- **Repo:** `/Users/borisserzhanovich/Projects/WorkoutTracker-repo`
- **Remote:** `origin` → `https://github.com/Borisserz/WorkoutTracker.git`
- **Default branch for design work:** `develop` (no `main` on remote; `origin/HEAD` → `develop`)
- **Xcode project:** `WorkoutTracker.xcodeproj`
- **Colleague fork (reference only):** `moggerrescure/WorkoutTracker` — do not assume dual-repo sync paths on this Mac
- **Docs index:** `docs/INDEX.md`

## Design system (source of truth)

- **Theme:** `PastelTheme` + `LuxuryPastelTheme` via `ThemeManager.current`
- **Appearance:** dark-only (`AppearanceMode.lockedRawValue`). Do not reintroduce Light/System UI unless a real light palette ships.
- **Palette:** OLED canvas `#0E0F12`, card `#17181D`, oat `#EFE3D3`, sage `#34C759`, amber `#FBBF24`, lavender `#A78BFA`, peach `#F87171`
- **Buttons:** `PastelTheme.ButtonMetrics` tiers 1–5 — fixed heights, no vertical padding for action height
- **Anti-slop:** no decorative middle dots, no ALL-CAPS chrome, no cyber neon gradients
- **Calendar:** `CalendarDayPressurePlate` in `WorkoutCalendarView.swift`
- **Backdrop:** `AtmosphericGymBackdropView` on main tabs

## Hard rules for agents

1. Prefer EN String Catalog keys (`Text("Overview")`); keep `ru` (and other) translations in `Localizable.xcstrings`.
2. Gate haptics through `HapticManager` (`hapticsEnabled` UserDefaults key).
3. Never `fatalError` after setting recoverable UI state (see `databaseLoadError`).
4. Do not revive `CyberNeonTheme` or neon accent colors.
5. Hub / Overview redesign is finished — extend, don’t rewrite from scratch.
6. **Single active workout** — start paths go through `WorkoutService` guards (`createWorkout` / `startGeneratedWorkout` / Watch `.startWorkout`). Do not insert a second active session.
7. **No invented readiness** — CNS `< 0` / missing vitals → “not measured”; never coerce to 100. Widget decoder must not invent tip/muscles.
8. **Sign-out ≠ wipe** — do not call `deleteLocalData()` on sign-out (CloudKit sync risk). Wipe only on account/profile delete or DEBUG Clear All; keep wipe parity (XP, widget, colors, avatar).
9. Prefer returned `PersistentIdentifier` from start APIs over `fetchLatestWorkout()` races.
10. Audit trail: `docs/INDEX.md` → full / residual / fix-status reports. ADR: `docs/adr/0001-session-safety-cns-signout.md`.

## Audit status (2026-11-01)

| Pass | Result |
|------|--------|
| Breaks B01–B28 | Fixed |
| Improve I01–I20 | Fixed (I17 deeper suites still optional) |
| Residual R01–R14 + J01–J16 | Fixed — see `docs/audits/2026-11-01-residual-fix-status.md` |
| Polish P0/P1 (CNS invent, Pastel accents, Explore honesty) | Fixed — see `docs/audits/2026-11-01-polish-pass.md` |
| Ideal pass (Profile EN, Rest honesty, full tests) | Fixed — see `docs/audits/2026-11-01-ideal-pass.md` |

## Local skills (optional)

Project-local `.agents/skills/` may be added later. Until then use global Cursor skills under `~/.cursor/skills/` (frontend-design, kill-ai-slop, swiftui-pro, etc.).

## Verification

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# Prefer a concrete simulator when available (iOS 26.3.x):
xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build

xcodebuild -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug test -only-testing:WorkoutTrackerTests
```

Fallback: `-destination 'generic/platform=iOS'`. Prefer a physical device when Simulator runtime is unavailable.

### Maestro E2E (Phase 1 smoke)

```bash
# Once: curl -Ls "https://get.maestro.mobile.dev" | bash
./scripts/maestro_run.sh smoke
```

Flows live in `.maestro/flows/` (`smoke`, `workout`, `overview`, `history` tags). Launch uses `-UITestMode` (skips onboarding + Health/Notifications/Speech sheets). Phase 2 covers empty-workout start/finish, Overview CNS honesty, History empty state.
