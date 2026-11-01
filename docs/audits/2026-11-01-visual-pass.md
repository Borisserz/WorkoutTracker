# Visual / PastelTheme pass — 2026-11-01

## Verdict

Main chrome (Workout Hub, tab bar, Legendary card, empty states) matches Pastel dark OLED. Fixed anti-slop copy/separators, AI Hub chrome, theme canvas mismatches, permission stacking, and eager speech prompt.

## Fixed

| Item | Change |
|------|--------|
| Middle-dot chrome | Anatomy / Hub / Progress / Calendar / Preset / Superset → em dash or comma |
| AI Hub subtitle + “Online 24/7” pill | Honest subtitle; removed glowing online badge |
| AI protocol sheets | `systemGroupedBackground` → `PastelTheme.canvas` |
| Legendary era chip | Dropped ALL-CAPS |
| Calendar workout dots | Removed neon sage glow |
| Speech on every AI Hub appear | Lazy: only when user starts listening |
| Notifications + Health stacked | Notifications after HealthKit `requestAuthorization` returns; skip if already decided |
| Speech usage string | Brand “Ai Workout” |

## Looks solid (from sim screenshots)

- Workout Hub: streak pill, week strip, Start workout / Legendary cards, oat tint tab bar
- History empty state: Pastel empty + CTA
- Progress shell (prior smoke): awards / goals cards on canvas
- Atmospheric backdrop + card `#17181D` language preserved

## Residual (not blockers)

- System date may be RU while EN catalog strings stay EN
- Cold launch still shows Health Access once (expected TCC)
- Simulator Space/window often unavailable for interactive multi-tab capture this session
- Optional: soften remaining `.textCase(.uppercase)` on share cards / chart section labels

## Evidence

`/tmp/wt-visual/` — launch / hub / fresh-install shots  
Build after visual fixes: SUCCEEDED
