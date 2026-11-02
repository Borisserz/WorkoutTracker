# Watch + Live Activity device smoke (~15 min)

**Why:** WCSession / Dynamic Island on Simulator lie. This closes the hardware confidence gap for dual-session + Live Activity.

**Gear:** paired iPhone + Apple Watch, both unlocked, WorkoutTracker + Watch app installed (same team/build), Bluetooth/Wi‑Fi on.

| # | Step (~min) | Pass criteria |
|---|-------------|-----------------|
| 1 | Open iPhone app; open Watch app (~1) | Both launch; no crash on Watch store |
| 2 | **Phone start** empty workout; glance Watch (~2) | Watch shows / can join active session (or sync banner); Island/Lock Screen Live Activity appears on iPhone |
| 3 | Log 1 set on phone; wait ~5s (~2) | Watch reflects set (or full-state refresh after `requestActiveState`) |
| 4 | Finish on phone (~1) | Live Activity gone; Watch not stuck in active workout |
| 5 | Start workout **on Watch** with phone idle (~2) | Session starts; phone gets active / banner |
| 6 | Finish on Watch (~1) | Both sides idle; no orphan `endTime == nil` |
| 7 | **Dual refuse:** start on phone, then start on Watch (~3) | Watch **refuses** / shows blocked; phone keeps single active |
| 8 | (Optional) Airplane Watch + companion installed, try Watch start (~2) | Fail-closed refuse (companion present, unreachable) |
| 9 | Kill/relaunch mid-session once (~2) | No second active after cleanup / resume |

**Fail → file:** note step #, Watch OS / iPhone OS, whether `isReachable` flickered (Console: category `Watch`).

**Timebox:** 15 min happy path (1–7). Steps 8–9 optional +5 min.

**Not a substitute for:** unit suite in `WatchConnectivityTests` (payload + gates + dual-start race).
