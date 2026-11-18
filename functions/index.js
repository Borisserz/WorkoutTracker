const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAppCheck } = require("firebase-admin/app-check");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { defineSecret } = require("firebase-functions/params");

// Per-user AI rate limit (abuse control). Quota is atomically reserved inside
// enforceRateLimit to prevent concurrent TOCTOU bypass and refunded on upstream 5xx.
const AI_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_AI_WEEKLY_LIMIT = 200;
const DEFAULT_ANON_AI_WEEKLY_LIMIT = 40;
const UPSTREAM_TIMEOUT_MS = 15000;
const TOTAL_RETRY_BUDGET_MS = 45000;
const STREAM_IDLE_TIMEOUT_MS = 25000;
const MAX_VERTEX_CONTENTS = 40;
const MAX_VERTEX_TEXT_CHARS = 60000;
const MAX_VERTEX_IMAGES = 4;
const MAX_VERTEX_IMAGE_BASE64_LEN = 6000000;
const ALLOWED_IMAGE_MIMES = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
  "image/heic",
]);
const PROJECT_NUMBER = "667537183554";

initializeApp();

// Stored in Secret Manager (not plain Cloud Run env). Comma-separate for key rotation.
const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");

const PROJECT_HINT = "serzhanovich-ecosystem-ce700";
const SERVICE_ACCOUNT =
  "firebase-adminsdk-fbsvc@serzhanovich-ecosystem-ce700.iam.gserviceaccount.com";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

// Live OpenRouter :free models with structured_outputs + response_format support, ordered by reliability.
const FREE_MODELS_STRUCTURED = [
  "particle-ai/particle-1:free",
  "nvidia/nemotron-3.5-super-vl:free",
  "baidu/ernie-5.5-flash-preview:free",
  "inclusionai/ling-3.2-flash:free",
  "liquid/lfm-3-1.7b:free",
  "dots-studio/dots-3-note-preview:free",
];
// Broader JSON/text fallbacks plus OpenRouter's auto-routing :free pool.
const FREE_MODELS_FALLBACK = [
  "google/gemma-4-26b-a4b-it:free",
  "google/gemma-4-31b-it:free",
  "recursive/flint-v1.0:free",
  "openrouter/free",
];
const VISION_MODELS = [
  "nvidia/nemotron-3.5-super-vl:free",
  "particle-ai/particle-1:free",
  "inclusionai/ling-3.2-flash:free",
  "dots-studio/dots-3-note-preview:free",
  "google/gemma-4-31b-it:free",
  "google/gemma-4-26b-a4b-it:free",
  "openrouter/free",
];

const STRUCTURED_MODELS = new Set([
  ...FREE_MODELS_STRUCTURED,
  "openrouter/free",
]);
const JSON_OBJECT_MODELS = new Set([
  ...STRUCTURED_MODELS,
  "google/gemma-4-26b-a4b-it:free",
  "google/gemma-4-31b-it:free",
  "recursive/flint-v1.0:free",
]);

const AUTO_BLOCK_REPORT_THRESHOLD = 3;

class RateLimitError extends Error {
  constructor(retryAfterSeconds, limit) {
    super("rate_limited");
    this.retryAfterSeconds = retryAfterSeconds;
    this.limit = limit;
  }
}

function parseApiKeys(raw) {
  const seen = new Set();
  const keys = [];
  for (const part of String(raw || "").split(",")) {
    const trimmed = part.trim();
    if (trimmed && !seen.has(trimmed)) {
      seen.add(trimmed);
      keys.push(trimmed);
    }
  }
  return keys;
}

function supportsResponseFormat(model) {
  return JSON_OBJECT_MODELS.has(model);
}

function hasImageContent(body) {
  if (!Array.isArray(body?.contents)) return false;
  return body.contents.some(
    (c) =>
      Array.isArray(c?.parts) &&
      c.parts.some((p) => p?.inlineData && p.inlineData.data)
  );
}

function geminiTypeToJson(type) {
  if (!type) return "string";
  const t = String(type).toUpperCase();
  switch (t) {
    case "OBJECT":
      return "object";
    case "ARRAY":
      return "array";
    case "INTEGER":
      return "integer";
    case "NUMBER":
      return "number";
    case "BOOLEAN":
      return "boolean";
    case "STRING":
    default:
      return "string";
  }
}

/** Convert Gemini/Vertex schema objects into plain JSON Schema. */
function convertGeminiSchema(schema) {
  if (!schema || typeof schema !== "object") return undefined;
  const out = { type: geminiTypeToJson(schema.type) };
  if (schema.description) out.description = schema.description;
  if (schema.properties && typeof schema.properties === "object") {
    out.properties = {};
    for (const [key, value] of Object.entries(schema.properties)) {
      out.properties[key] = convertGeminiSchema(value);
    }
  }
  if (schema.items) out.items = convertGeminiSchema(schema.items);
  if (Array.isArray(schema.required)) out.required = schema.required;
  return out;
}

function geminiPartsToOpenAIContent(parts) {
  if (!Array.isArray(parts)) return "";
  const hasInlineImage = parts.some((p) => p?.inlineData && p.inlineData.data);
  if (!hasInlineImage) {
    return parts.map((p) => p?.text).filter(Boolean).join("\n");
  }
  const items = [];
  for (const p of parts) {
    if (typeof p?.text === "string" && p.text) {
      items.push({ type: "text", text: p.text });
    } else if (p?.inlineData?.data) {
      const mimeType = p.inlineData.mimeType || "image/jpeg";
      items.push({
        type: "image_url",
        image_url: { url: `data:${mimeType};base64,${p.inlineData.data}` },
      });
    }
  }
  return items.length > 0 ? items : "";
}

/**
 * Verify an already-decoded Firebase App Check token response belongs to this Firebase project
 * (or an explicit comma-separated ALLOWED_APP_IDS env override).
 */
function verifyAllowedAppCheck(verified) {
  const appId = typeof verified?.appId === "string" ? verified.appId.trim() : "";
  if (!appId) return false;
  const rawAllowlist = String(process.env.ALLOWED_APP_IDS || "").trim();
  if (rawAllowlist) {
    const allowed = new Set(parseApiKeys(rawAllowlist));
    return allowed.has(appId);
  }
  return appId.startsWith(`1:${PROJECT_NUMBER}:`);
}

function validateVertexProxyBody(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, error: "Request body must be a JSON object." };
  }
  if (!Array.isArray(body.contents) || body.contents.length === 0) {
    return { ok: false, error: "contents must be a non-empty array." };
  }
  if (body.contents.length > MAX_VERTEX_CONTENTS) {
    return { ok: false, error: `contents exceeds ${MAX_VERTEX_CONTENTS} turns.` };
  }

  let totalTextChars = 0;
  let totalImages = 0;

  const inspectParts = (parts) => {
    if (!Array.isArray(parts)) return null;
    for (const p of parts) {
      if (typeof p?.text === "string") {
        totalTextChars += p.text.length;
        if (totalTextChars > MAX_VERTEX_TEXT_CHARS) {
          return `Total prompt length exceeds ${MAX_VERTEX_TEXT_CHARS} characters.`;
        }
      }
      if (p?.inlineData && p.inlineData.data !== undefined) {
        totalImages += 1;
        if (totalImages > MAX_VERTEX_IMAGES) {
          return `Image count exceeds ${MAX_VERTEX_IMAGES}.`;
        }
        if (typeof p.inlineData.data !== "string" || p.inlineData.data.length === 0) {
          return "inlineData.data must be a non-empty base64 string.";
        }
        if (p.inlineData.data.length > MAX_VERTEX_IMAGE_BASE64_LEN) {
          return "inlineData image exceeds maximum allowed size.";
        }
        const mime = String(p.inlineData.mimeType || "image/jpeg").toLowerCase();
        if (!ALLOWED_IMAGE_MIMES.has(mime)) {
          return `Unsupported inlineData mimeType: ${mime}`;
        }
      }
    }
    return null;
  };

  if (body.systemInstruction?.parts) {
    const sysErr = inspectParts(body.systemInstruction.parts);
    if (sysErr) return { ok: false, error: sysErr };
  }

  for (const content of body.contents) {
    if (!content || typeof content !== "object") {
      return { ok: false, error: "Each content entry must be an object." };
    }
    const err = inspectParts(content.parts);
    if (err) return { ok: false, error: err };
  }

  return { ok: true };
}

/**
 * Translate the iOS GeminiRequest body into an OpenAI-compatible Chat Completions body.
 */
function geminiBodyToOpenAI(body, { streaming, model }) {
  const messages = [];
  const systemParts = body?.systemInstruction?.parts;
  if (Array.isArray(systemParts)) {
    const systemText = systemParts
      .map((p) => p?.text)
      .filter(Boolean)
      .join("\n");
    if (systemText) messages.push({ role: "system", content: systemText });
  }

  if (Array.isArray(body?.contents)) {
    for (const content of body.contents) {
      // Never permit client conversation items to inject "system" or "tool" roles.
      const role = content.role === "model" ? "assistant" : "user";
      const mapped = geminiPartsToOpenAIContent(content.parts);
      if (
        (typeof mapped === "string" && mapped) ||
        (Array.isArray(mapped) && mapped.length > 0)
      ) {
        messages.push({ role, content: mapped });
      }
    }
  }

  const gen = body?.generationConfig || {};
  const rawTemp = typeof gen.temperature === "number" && Number.isFinite(gen.temperature)
    ? gen.temperature
    : 0.4;
  const temperature = Math.min(Math.max(rawTemp, 0), 1.5);
  const rawMax = typeof gen.maxOutputTokens === "number" && Number.isFinite(gen.maxOutputTokens)
    ? Math.floor(gen.maxOutputTokens)
    : 4096;
  const maxTokens = Math.min(Math.max(rawMax, 1), 4096);

  const openAIBody = {
    model,
    messages,
    temperature,
    max_tokens: maxTokens,
    stream: Boolean(streaming),
    // Helps free models return parseable JSON when they drift.
    plugins: [{ id: "response-healing" }],
  };

  const wantsJson =
    gen.responseMimeType === "application/json" || Boolean(gen.responseSchema);
  if (wantsJson && supportsResponseFormat(model)) {
    const jsonSchema = convertGeminiSchema(gen.responseSchema);
    if (jsonSchema && STRUCTURED_MODELS.has(model)) {
      openAIBody.response_format = {
        type: "json_schema",
        json_schema: {
          name: "workout_tracker_response",
          strict: false,
          schema: jsonSchema,
        },
      };
    } else {
      openAIBody.response_format = { type: "json_object" };
    }
  }

  return openAIBody;
}

function stripModelJSON(raw) {
  let text = String(raw || "").trim();
  if (text.startsWith("```")) {
    const nl = text.indexOf("\n");
    if (nl >= 0) text = text.slice(nl + 1);
    const end = text.lastIndexOf("```");
    if (end >= 0) text = text.slice(0, end);
    text = text.trim();
  }
  try {
    JSON.parse(text);
    return text;
  } catch {
    /* continue */
  }
  const objStart = text.indexOf("{");
  const objEnd = text.lastIndexOf("}");
  if (objStart >= 0 && objEnd > objStart) {
    const slice = text.slice(objStart, objEnd + 1);
    try {
      JSON.parse(slice);
      return slice;
    } catch {
      /* keep original */
    }
  }
  return text;
}

function openAIToGeminiResponse(data, { expectJSON = false } = {}) {
  let text =
    data?.choices?.[0]?.message?.content ??
    data?.choices?.[0]?.text ??
    "";
  if (typeof text !== "string") text = JSON.stringify(text);
  if (expectJSON) text = stripModelJSON(text);
  return {
    candidates: [
      {
        content: {
          parts: [{ text }],
        },
      },
    ],
  };
}

function openAIStreamChunkToGemini(line) {
  // OpenAI SSE: data: {...} or data: [DONE]
  if (!line.startsWith("data:")) return null;
  const payload = line.slice(5).trim();
  if (!payload || payload === "[DONE]") return payload === "[DONE]" ? "[DONE]" : null;
  try {
    const parsed = JSON.parse(payload);
    if (parsed?.error) {
      const msg = String(parsed.error.message || "Upstream stream error").slice(0, 300);
      const code = Number.isFinite(parsed.error.code) ? parsed.error.code : 502;
      return JSON.stringify({ error: { code, message: msg } });
    }
    const delta =
      parsed?.choices?.[0]?.delta?.content ??
      parsed?.choices?.[0]?.message?.content ??
      "";
    if (!delta) return null;
    return JSON.stringify({
      candidates: [{ content: { parts: [{ text: delta }] } }],
    });
  } catch {
    return null;
  }
}

function computeRateLimitReservation({
  existingData,
  now = Date.now(),
  limit = DEFAULT_AI_WEEKLY_LIMIT,
  windowMs = AI_WINDOW_MS,
}) {
  let windowStart = now;
  let currentCount = 0;

  if (existingData && typeof existingData === "object") {
    const ws = typeof existingData.windowStart === "number" ? existingData.windowStart : 0;
    if (now - ws < windowMs) {
      windowStart = ws;
      currentCount = typeof existingData.count === "number" ? existingData.count : 0;
    }
  }

  if (currentCount >= limit) {
    const retryAfterSeconds = Math.max(
      1,
      Math.ceil((windowStart + windowMs - now) / 1000)
    );
    return { allowed: false, retryAfterSeconds, windowStart, nextCount: currentCount };
  }

  return {
    allowed: true,
    retryAfterSeconds: 0,
    windowStart,
    nextCount: currentCount + 1,
  };
}

async function fetchWithTimeout(url, options, timeoutMs = UPSTREAM_TIMEOUT_MS) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function enforceRateLimit(uid, { isAnonymous = false } = {}) {
  const db = getFirestore();
  const configSnap = await db.collection("config").doc("ai_settings").get();
  const configData = configSnap.data() || {};
  const signedInLimit =
    typeof configData.weeklyLimit === "number"
      ? configData.weeklyLimit
      : DEFAULT_AI_WEEKLY_LIMIT;
  const anonLimit =
    typeof configData.anonymousWeeklyLimit === "number"
      ? configData.anonymousWeeklyLimit
      : DEFAULT_ANON_AI_WEEKLY_LIMIT;
  const aiWeeklyLimit = isAnonymous
    ? Math.min(signedInLimit, anonLimit)
    : signedInLimit;

  const ref = db.collection("ai_usage").doc(uid);

  // Atomically reserve a slot inside the transaction so concurrent requests cannot race.
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const decision = computeRateLimitReservation({
      existingData: snap.exists ? snap.data() : null,
      now,
      limit: aiWeeklyLimit,
      windowMs: AI_WINDOW_MS,
    });

    if (!decision.allowed) {
      throw new RateLimitError(decision.retryAfterSeconds, aiWeeklyLimit);
    }

    tx.set(
      ref,
      {
        windowStart: decision.windowStart,
        count: decision.nextCount,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  return aiWeeklyLimit;
}

async function releaseRateLimitSlot(uid) {
  const db = getFirestore();
  const ref = db.collection("ai_usage").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const data = snap.data() || {};
    const current = typeof data.count === "number" ? data.count : 0;
    if (current <= 0) return;
    tx.set(
      ref,
      {
        count: current - 1,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

function modelChainForRequest(body) {
  if (hasImageContent(body)) {
    return [...VISION_MODELS];
  }
  const wantsSchema = Boolean(body?.generationConfig?.responseSchema);
  if (wantsSchema) {
    return [...FREE_MODELS_STRUCTURED, ...FREE_MODELS_FALLBACK];
  }
  // Prefer low-latency reliable models for plain chat/stream, then the rest.
  return [
    "particle-ai/particle-1:free",
    "nvidia/nemotron-3.5-super-vl:free",
    ...FREE_MODELS_STRUCTURED.filter(
      (m) =>
        m !== "particle-ai/particle-1:free" &&
        m !== "nvidia/nemotron-3.5-super-vl:free"
    ),
    ...FREE_MODELS_FALLBACK,
  ];
}

async function callOpenRouterText({
  apiKeys,
  geminiBody,
  timeoutMs = UPSTREAM_TIMEOUT_MS,
  maxBudgetMs = TOTAL_RETRY_BUDGET_MS,
}) {
  const chain = modelChainForRequest(geminiBody);
  const expectJSON =
    geminiBody?.generationConfig?.responseMimeType === "application/json" ||
    Boolean(geminiBody?.generationConfig?.responseSchema);
  const deadline = Date.now() + maxBudgetMs;

  let lastError = null;
  for (const apiKey of apiKeys) {
    for (let i = 0; i < chain.length; i++) {
      const remainingMs = deadline - Date.now();
      if (remainingMs <= 500) {
        lastError = lastError || new Error("OpenRouter retry budget exceeded");
        break;
      }
      const model = chain[i];
      const attempt = geminiBodyToOpenAI(geminiBody, {
        streaming: false,
        model,
      });

      try {
        const controller = new AbortController();
        const perRequestMs = Math.min(timeoutMs, remainingMs);
        const timer = setTimeout(() => controller.abort(), perRequestMs);
        let text;
        let ok;
        let status;
        try {
          const resp = await fetch(OPENROUTER_URL, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${apiKey}`,
              "Content-Type": "application/json",
              "HTTP-Referer": `https://${PROJECT_HINT}.web.app`,
              "X-OpenRouter-Title": "WorkoutTracker",
            },
            body: JSON.stringify(attempt),
            signal: controller.signal,
          });
          ok = resp.ok;
          status = resp.status;
          text = await resp.text();
        } finally {
          clearTimeout(timer);
        }

        if (!ok) {
          const snippet = text.slice(0, 400);
          lastError = new Error(`OpenRouter ${status} ${model}: ${snippet}`);
          lastError.httpStatus = status;
          console.warn(lastError.message);
          if (status === 429 && snippet.includes("free-models-per-day")) {
            break;
          }
          continue;
        }
        const data = JSON.parse(text);
        const gemini = openAIToGeminiResponse(data, { expectJSON });
        const outText = gemini.candidates?.[0]?.content?.parts?.[0]?.text || "";
        if (!outText) {
          lastError = new Error(`Empty completion from ${model}`);
          continue;
        }
        if (expectJSON) {
          // Verify JSON actually parses; otherwise fall through to next model.
          JSON.parse(outText);
        }
        return gemini;
      } catch (e) {
        lastError = new Error(`OpenRouter err ${model}: ${String(e?.message || e).slice(0, 300)}`);
        console.warn(lastError.message);
      }
    }
    if (deadline - Date.now() <= 500) break;
  }
  throw lastError || new Error("OpenRouter text call failed");
}

function resolveReportUpdate({
  currentData,
  alreadyReportedByUser,
  threshold = AUTO_BLOCK_REPORT_THRESHOLD,
}) {
  if (alreadyReportedByUser) return null;
  const newCount = ((currentData && currentData.reportCount) || 0) + 1;
  const shouldBlock =
    newCount >= threshold && currentData?.status !== "blocked";
  return { reportCount: newCount, shouldBlock };
}

async function readChunkWithTimeout(reader, timeoutMs = STREAM_IDLE_TIMEOUT_MS) {
  let timer = null;
  try {
    return await Promise.race([
      reader.read(),
      new Promise((_, reject) => {
        timer = setTimeout(() => {
          reject(new Error("Upstream SSE idle timeout"));
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}

// ==========================================
// 1) HTTP proxy for the iOS client
// ==========================================
exports.vertexProxy = onRequest(
  {
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    memory: "512MiB",
    timeoutSeconds: 300,
    maxInstances: 20,
    secrets: [openRouterApiKey],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    const appCheckToken = req.header("X-Firebase-AppCheck");
    if (!appCheckToken) {
      res.status(401).json({ error: "Missing App Check token" });
      return;
    }
    try {
      const verified = await getAppCheck().verifyToken(appCheckToken);
      if (!verifyAllowedAppCheck(verified)) {
        res.status(403).json({ error: "App Check app ID not allowed" });
        return;
      }
    } catch (e) {
      res.status(401).json({ error: "Invalid App Check token" });
      return;
    }

    const authHeader = req.header("Authorization") || "";
    const m = authHeader.match(/^Bearer (.+)$/i);
    if (!m) {
      res.status(401).json({ error: "Missing Firebase ID token" });
      return;
    }
    let uid;
    let isAnonymous = false;
    try {
      const decoded = await getAuth().verifyIdToken(m[1]);
      uid = decoded.uid;
      isAnonymous = decoded?.firebase?.sign_in_provider === "anonymous";
    } catch (e) {
      res.status(401).json({ error: "Invalid Firebase ID token" });
      return;
    }

    const body = req.body || {};
    const validation = validateVertexProxyBody(body);
    if (!validation.ok) {
      res.status(400).json({ error: "invalid_request", message: validation.error });
      return;
    }

    try {
      await enforceRateLimit(uid, { isAnonymous });
    } catch (e) {
      if (e instanceof RateLimitError) {
        res.set("Retry-After", String(e.retryAfterSeconds));
        res.status(429).json({
          error: "weekly_limit_reached",
          message: `You've reached your weekly limit of ${e.limit} AI requests.`,
          retryAfter: e.retryAfterSeconds,
        });
        return;
      }
      console.error("Rate limit check failed:", e);
      res.status(500).json({ error: "Rate limit check failed" });
      return;
    }

    const apiKeys = parseApiKeys(openRouterApiKey.value());
    if (apiKeys.length === 0) {
      await releaseRateLimitSlot(uid).catch(() => {});
      res.status(500).json({ error: "AI service not configured" });
      return;
    }

    const streaming = req.query.stream === "true";
    const chain = modelChainForRequest(body);
    let yielded = false;
    let reserved = true;

    const refundQuotaIfUnused = async () => {
      if (!yielded && reserved) {
        reserved = false;
        await releaseRateLimitSlot(uid).catch(() => {});
      }
    };

    try {
      if (!streaming) {
        const gemini = await callOpenRouterText({ apiKeys, geminiBody: body });
        yielded = true;
        res.status(200).json(gemini);
        return;
      }

      // Streaming: try models until one returns a live SSE body within total retry budget.
      const deadline = Date.now() + TOTAL_RETRY_BUDGET_MS;
      let upstream = null;
      let lastError = null;
      for (const apiKey of apiKeys) {
        for (let i = 0; i < chain.length; i++) {
          const remainingMs = deadline - Date.now();
          if (remainingMs <= 500) {
            lastError = lastError || new Error("Streaming retry budget exceeded");
            break;
          }
          const model = chain[i];
          const attempt = geminiBodyToOpenAI(body, { streaming: true, model });
          try {
            const resp = await fetchWithTimeout(
              OPENROUTER_URL,
              {
                method: "POST",
                headers: {
                  Authorization: `Bearer ${apiKey}`,
                  "Content-Type": "application/json",
                  "HTTP-Referer": `https://${PROJECT_HINT}.web.app`,
                  "X-OpenRouter-Title": "WorkoutTracker",
                },
                body: JSON.stringify(attempt),
              },
              Math.min(UPSTREAM_TIMEOUT_MS, remainingMs)
            );
            if (!resp.ok || !resp.body) {
              const snippet = (await resp.text()).slice(0, 300);
              lastError = new Error(
                `stream ${resp.status} ${model}: ${snippet}`
              );
              lastError.httpStatus = resp.status;
              console.warn(lastError.message);
              if (resp.status === 429 && snippet.includes("free-models-per-day")) {
                break;
              }
              continue;
            }
            upstream = resp;
            break;
          } catch (e) {
            lastError = new Error(
              `stream err ${model}: ${String(e?.message || e).slice(0, 300)}`
            );
            console.warn(lastError.message);
          }
        }
        if (upstream || deadline - Date.now() <= 500) break;
      }

      if (!upstream) {
        throw lastError || new Error("All streaming models failed");
      }

      res.status(200).set("Content-Type", "text/event-stream");
      const reader = upstream.body.getReader();
      let clientDisconnected = false;
      const onClose = () => {
        clientDisconnected = true;
        Promise.resolve(reader.cancel()).catch(() => {});
      };
      req.on("close", onClose);

      try {
        const decoder = new TextDecoder();
        let buffer = "";
        let streamErrorSeen = false;
        while (!clientDisconnected) {
          const { done, value } = await readChunkWithTimeout(reader);
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() || "";
          for (const rawLine of lines) {
            const line = rawLine.trimEnd();
            if (!line) continue;
            const converted = openAIStreamChunkToGemini(line);
            if (converted === "[DONE]") {
              res.write("data: [DONE]\n\n");
              continue;
            }
            if (converted) {
              if (converted.startsWith('{"error":')) {
                streamErrorSeen = true;
                res.write(`data: ${converted}\n\n`);
                break;
              }
              yielded = true;
              res.write(`data: ${converted}\n\n`);
            }
          }
          if (streamErrorSeen) break;
        }
      } finally {
        req.off("close", onClose);
      }

      if (!yielded) {
        await refundQuotaIfUnused();
      }
      res.end();
    } catch (e) {
      console.error("vertexProxy OpenRouter error:", e);
      await refundQuotaIfUnused();
      if (!res.headersSent) {
        if (e?.httpStatus === 429) {
          res.set("Retry-After", "60");
          return res.status(429).json({
            error: "upstream_rate_limited",
            retryAfter: 60,
            message: "Upstream AI rate limit exceeded. Please try again later.",
          });
        }
        res.status(502).json({
          error: "upstream_failed",
          message: "Upstream AI service temporarily unavailable. Please try again.",
        });
      } else {
        res.end();
      }
    }
  }
);

function collectExerciseModerationLines(exercise, out, depth = 0) {
  if (!exercise || typeof exercise !== "object" || depth > 2) return;
  const name = String(exercise.name || "").slice(0, 200).trim();
  const muscle = String(exercise.muscleGroup || "").slice(0, 100).trim();
  const notes = String(exercise.notes || "").slice(0, 500).trim();
  const parts = [name, muscle, notes].filter(Boolean);
  if (parts.length > 0) out.push(parts.join(" — "));
  if (Array.isArray(exercise.subExercises)) {
    for (const sub of exercise.subExercises.slice(0, 20)) {
      collectExerciseModerationLines(sub, out, depth + 1);
    }
  }
}

function extractModeratedWorkoutText(data) {
  const title = String(data?.title || "").slice(0, 300).trim();
  const name = String(data?.name || "").slice(0, 300).trim();
  const folderName = String(data?.folderName || "").slice(0, 200).trim();
  const description = String(data?.description || "").slice(0, 2000).trim();
  const exercises = Array.isArray(data?.exercises)
    ? data.exercises.slice(0, 200)
    : [];

  const exerciseLines = [];
  for (const ex of exercises) {
    collectExerciseModerationLines(ex, exerciseLines, 0);
  }

  return [
    `TITLE: ${title}`,
    name && name !== title ? `NAME: ${name}` : "",
    folderName ? `FOLDER: ${folderName}` : "",
    `DESCRIPTION: ${description}`,
    `EXERCISES:\n${exerciseLines.join("\n")}`,
  ]
    .filter(Boolean)
    .join("\n")
    .slice(0, 16000);
}

// ==========================================
// 2) Auto-moderation of every new shared workout
// ==========================================
exports.moderateSharedWorkout = onDocumentCreated(
  {
    document: "shared_workouts/{workoutId}",
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    maxInstances: 20,
    secrets: [openRouterApiKey],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const ref = snap.ref;

    const systemPrompt = `You are a strict content moderator for a fitness app.
Decide if user-submitted workout text is acceptable on a public platform that may be used by minors.
BLOCK any of:
- Sexual content, suggestive language, or pornography
- Hate speech, slurs, harassment of any group
- Threats, violence promotion, self-harm encouragement
- Illegal activity, drug promotion (including PEDs as instructions), spam, advertising
- Personal data (phone numbers, emails, home addresses)
- Off-topic content unrelated to fitness/workouts
APPROVE otherwise.
Respond ONLY with JSON: {"decision":"approved"|"blocked","reason":"short reason"}.`;

    const userPayload = extractModeratedWorkoutText(data);

    let decision = "blocked";
    let reason = "Moderation service error";

    try {
      const apiKeys = parseApiKeys(openRouterApiKey.value());
      const geminiBody = {
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents: [{ role: "user", parts: [{ text: userPayload }] }],
        generationConfig: {
          temperature: 0.0,
          responseMimeType: "application/json",
          responseSchema: {
            type: "OBJECT",
            properties: {
              decision: { type: "STRING" },
              reason: { type: "STRING" },
            },
            required: ["decision", "reason"],
          },
        },
      };
      const gemini = await callOpenRouterText({ apiKeys, geminiBody });
      const text = gemini?.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
      const parsed = JSON.parse(text);
      if (parsed.decision === "approved" || parsed.decision === "blocked") {
        decision = parsed.decision;
        reason = String(parsed.reason || "").slice(0, 500);
      }
    } catch (e) {
      console.error("Moderation error:", e);
      decision = "blocked";
      reason =
        e?.httpStatus === 429
          ? "Moderation service is temporarily busy. Please try again in a minute."
          : "Moderation service error";
    }

    await ref.update({
      status: decision,
      moderationReason: reason,
      moderatedAt: FieldValue.serverTimestamp(),
    });

    console.log(
      `Moderated workout ${event.params.workoutId}: ${decision}`
    );
  }
);

// ==========================================
// 3) On every report — deduplicate per reporter + auto-block past threshold
// ==========================================
exports.onReportCreated = onDocumentCreated(
  {
    document: "reports/{reportId}",
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    maxInstances: 20,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const workoutId = data.workoutId;
    // Skip FitRPG reports (app == "fitrpg", no workoutId).
    if (!workoutId || typeof workoutId !== "string") {
      return;
    }

    const db = getFirestore();
    const workoutRef = db.collection("shared_workouts").doc(workoutId);
    const reporterUid =
      typeof data.reporterUid === "string" && data.reporterUid.trim()
        ? data.reporterUid.trim()
        : null;

    try {
      await db.runTransaction(async (tx) => {
        const doc = await tx.get(workoutRef);
        if (!doc.exists) {
          console.warn(`Reported workout ${workoutId} does not exist`);
          return;
        }
        const reporterRef = reporterUid
          ? workoutRef.collection("reporters").doc(reporterUid)
          : null;
        const alreadyReportedByUser = reporterRef
          ? (await tx.get(reporterRef)).exists
          : false;

        const outcome = resolveReportUpdate({
          currentData: doc.data() || {},
          alreadyReportedByUser,
          threshold: AUTO_BLOCK_REPORT_THRESHOLD,
        });
        if (!outcome) {
          console.log(
            `Duplicate report ${event.params.reportId} ignored for workout ${workoutId}`
          );
          return;
        }

        const updates = { reportCount: outcome.reportCount };
        if (outcome.shouldBlock) {
          updates.status = "blocked";
          updates.moderationReason = `Auto-blocked after ${outcome.reportCount} user reports`;
          updates.moderatedAt = FieldValue.serverTimestamp();
        }
        if (reporterRef) {
          tx.set(reporterRef, {
            reportId: event.params.reportId,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
        tx.update(workoutRef, updates);
      });
      console.log(
        `Report ${event.params.reportId} processed for workout ${workoutId}`
      );
    } catch (e) {
      console.error("Report processing error:", e);
    }
  }
);

// ==========================================
// 4) Full account + data deletion (Guideline 5.1.1(v))
// ==========================================
async function deleteUserAccountData(db, auth, uid, { deleteAuth = true } = {}) {
  const sharedSnap = await db
    .collection("shared_workouts")
    .where("creatorUid", "==", uid)
    .get();

  // Recursively delete each shared workout (including any `reporters` subcollection).
  for (const sharedDoc of sharedSnap.docs) {
    await db.recursiveDelete(sharedDoc.ref);
  }

  const reportsSnap = await db
    .collection("reports")
    .where("reporterUid", "==", uid)
    .get();

  const reportRefs = reportsSnap.docs.map((d) => d.ref);
  for (let i = 0; i < reportRefs.length; i += 450) {
    const batch = db.batch();
    reportRefs.slice(i, i + 450).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }

  await db.recursiveDelete(db.collection("users").doc(uid));
  await db.collection("ai_usage").doc(uid).delete();

  if (deleteAuth !== false && auth && typeof auth.deleteUser === "function") {
    try {
      await auth.deleteUser(uid);
    } catch (err) {
      if (err?.code !== "auth/user-not-found") {
        throw err;
      }
    }
  }
}

exports.deleteAccount = onCall(
  {
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    enforceAppCheck: true,
    memory: "512MiB",
    timeoutSeconds: 300,
    maxInstances: 10,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to delete your account."
      );
    }
    if (request.app && !verifyAllowedAppCheck(request.app)) {
      throw new HttpsError("permission-denied", "Unsupported client application.");
    }

    const deleteAuth = request.data?.deleteAuthUser !== false;
    await deleteUserAccountData(getFirestore(), getAuth(), uid, { deleteAuth });

    return { ok: true };
  }
);

// Exported for local unit/smoke tests (not a Cloud Function).
module.exports._test = {
  geminiBodyToOpenAI,
  openAIToGeminiResponse,
  openAIStreamChunkToGemini,
  convertGeminiSchema,
  modelChainForRequest,
  parseApiKeys,
  stripModelJSON,
  hasImageContent,
  supportsResponseFormat,
  resolveReportUpdate,
  extractModeratedWorkoutText,
  validateVertexProxyBody,
  computeRateLimitReservation,
  verifyAppCheckResponse: verifyAllowedAppCheck,
  UPSTREAM_TIMEOUT_MS,
  FREE_MODELS_STRUCTURED,
  FREE_MODELS_FALLBACK,
  VISION_MODELS,
  callOpenRouterText,
  deleteUserAccountData,
};
