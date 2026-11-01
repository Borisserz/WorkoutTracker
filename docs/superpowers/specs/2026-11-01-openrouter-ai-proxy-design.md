# OpenRouter AI Proxy — Design

**Date:** 2026-11-01  
**Scope:** WorkoutTracker only (`functions/` + AI network client). Shared Firebase project — do not touch other apps.

## Goal

Replace Vertex/Gemini backend with OpenRouter **free** models, keep the iOS App Check + Firebase Auth gate, support model (+ optional key) fallback, and fix rate-limit/retry footguns.

## Architecture

```
iOS AILogicService → GeminiNetworkClient (unchanged request shape)
  → HTTPS vertexProxy (same Cloud Run URL / export name)
  → translate Gemini body → OpenAI Chat Completions
  → OpenRouter /api/v1/chat/completions (free model chain)
  → translate response → Gemini-shaped JSON/SSE for iOS
```

- API key(s) live in Secret Manager as `OPENROUTER_API_KEY` (comma-separated for key rotation), mounted via `defineSecret`. Local smoke uses gitignored `.secret.local` only.
- Function export name stays `vertexProxy` so the existing client URL keeps working.
- Moderation (`moderateSharedWorkout`) uses the same OpenRouter helper.

## Model chain (free, structured-first)

Primary → fallbacks (skip on 429/5xx/empty):

1. `xingchen-agi/xing4.0-29b-a4b:free` (structured)
2. `liquid/lfm-2.5-2.6b:free` (fast + structured)
3. `dots-studio/dots-3-note-preview:free` (structured)
4. `nvidia/nemotron-3.5-super-vl:free` (structured)
5. `google/gemma-4-26b-a4b-it:free` (response_format only)
6. `recursive/flint-v1.0:free`

When `responseSchema` is present, prefer models that advertise `structured_outputs`; otherwise any free model in the chain.

## Rate limit / retry fixes

- App weekly limit: count **successful** upstream AI calls only (not failed attempts).
- Default weekly ceiling raised for free-tier testing (`config/ai_settings.weeklyLimit`, default 200).
- iOS: do **not** exponential-retry app `weekly_limit_reached` 429s (wastes quota / UX).
- OpenRouter 429/5xx: server walks model list (and next API key if configured) before failing.

## Client hardening (done)

- `AIResponseParsing.extractJSONObject` before every Codable decode
- Stronger JSON rules in builder / smart / weekly / program / chat prompts
- On-device `AIIntentClassifier` (no extra OpenRouter call for routing)
- Richer streamed chat context (PRs + fatigue)
- iOS no longer retries app weekly 429s

## Out of scope

- Renaming Swift `Gemini*` types
- Putting OpenRouter key on device
- Wiring dead APIs (`analyzeActiveWorkout`, `calculateOptimalRecoveryTime`) until UI needs them
