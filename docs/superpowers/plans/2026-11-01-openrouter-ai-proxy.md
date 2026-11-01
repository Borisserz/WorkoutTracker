# Plan: OpenRouter AI Proxy

> Spec: `docs/superpowers/specs/2026-11-01-openrouter-ai-proxy-design.md`

## Tasks

1. Rewrite `functions/index.js` — Gemini→OpenAI translate, free model chain, success-only rate limit, moderation on OpenRouter.
2. Store `OPENROUTER_API_KEY` in Firebase secret + local `.secret.local` (gitignored).
3. Fix iOS `GeminiNetworkClient` — stop retrying weekly 429.
4. Smoke test via `npm run smoke` in `functions/`.
5. Deploy: `firebase functions:secrets:set OPENROUTER_API_KEY` then `firebase deploy --only functions:vertexProxy,functions:moderateSharedWorkout`.
