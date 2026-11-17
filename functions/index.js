const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAppCheck } = require("firebase-admin/app-check");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { defineSecret } = require("firebase-functions/params");

// Per-user AI rate limit (abuse control). With free OpenRouter models we still
// cap abuse, but count only successful upstream calls.
const AI_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_AI_WEEKLY_LIMIT = 200;
const UPSTREAM_TIMEOUT_MS = 15000;

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
      const role = content.role === "model" ? "assistant" : content.role || "user";
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
  const temperature =
    typeof gen.temperature === "number" ? gen.temperature : 0.4;
  const openAIBody = {
    model,
    messages,
    temperature,
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

async function fetchWithTimeout(url, options, timeoutMs = UPSTREAM_TIMEOUT_MS) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function enforceRateLimit(uid) {
  const db = getFirestore();
  const configSnap = await db.collection("config").doc("ai_settings").get();
  const configData = configSnap.data() || {};
  const aiWeeklyLimit =
    typeof configData.weeklyLimit === "number"
      ? configData.weeklyLimit
      : DEFAULT_AI_WEEKLY_LIMIT;

  const ref = db.collection("ai_usage").doc(uid);

  // Pre-check only (no increment). Successful calls call recordSuccessfulAIUse.
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    let windowStart = now;
    let count = 0;

    if (snap.exists) {
      const data = snap.data() || {};
      const ws = typeof data.windowStart === "number" ? data.windowStart : 0;
      if (now - ws < AI_WINDOW_MS) {
        windowStart = ws;
        count = data.count || 0;
      }
    }

    if (count >= aiWeeklyLimit) {
      const retryAfterSeconds = Math.ceil(
        (windowStart + AI_WINDOW_MS - now) / 1000
      );
      throw new RateLimitError(retryAfterSeconds, aiWeeklyLimit);
    }
  });

  return aiWeeklyLimit;
}

async function recordSuccessfulAIUse(uid) {
  const db = getFirestore();
  const ref = db.collection("ai_usage").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    let windowStart = now;
    let count = 0;
    if (snap.exists) {
      const data = snap.data() || {};
      const ws = typeof data.windowStart === "number" ? data.windowStart : 0;
      if (now - ws < AI_WINDOW_MS) {
        windowStart = ws;
        count = data.count || 0;
      }
    }
    tx.set(
      ref,
      {
        windowStart,
        count: count + 1,
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

async function callOpenRouterText({ apiKeys, geminiBody, timeoutMs = UPSTREAM_TIMEOUT_MS }) {
  const chain = modelChainForRequest(geminiBody);
  const expectJSON =
    geminiBody?.generationConfig?.responseMimeType === "application/json" ||
    Boolean(geminiBody?.generationConfig?.responseSchema);

  let lastError = null;
  for (const apiKey of apiKeys) {
    for (let i = 0; i < chain.length; i++) {
      const model = chain[i];
      const attempt = geminiBodyToOpenAI(geminiBody, {
        streaming: false,
        model,
      });

      try {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), timeoutMs);
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
          lastError = new Error(`OpenRouter ${status} ${model}: ${text.slice(0, 400)}`);
          console.warn(lastError.message);
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

// ==========================================
// 1) HTTP proxy for the iOS client
// ==========================================
exports.vertexProxy = onRequest(
  {
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    memory: "512MiB",
    timeoutSeconds: 300,
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
      await getAppCheck().verifyToken(appCheckToken);
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
    try {
      const decoded = await getAuth().verifyIdToken(m[1]);
      uid = decoded.uid;
    } catch (e) {
      res.status(401).json({ error: "Invalid Firebase ID token" });
      return;
    }

    try {
      await enforceRateLimit(uid);
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
      res.status(500).json({ error: "OPENROUTER_API_KEY not configured" });
      return;
    }

    const body = req.body || {};
    const streaming = req.query.stream === "true";
    const chain = modelChainForRequest(body);

    try {
      if (!streaming) {
        const gemini = await callOpenRouterText({ apiKeys, geminiBody: body });
        await recordSuccessfulAIUse(uid);
        res.status(200).json(gemini);
        return;
      }

      // Streaming: try models until one returns a live SSE body (timeout on initial handshake).
      let upstream = null;
      let lastError = null;
      for (const apiKey of apiKeys) {
        for (let i = 0; i < chain.length; i++) {
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
              UPSTREAM_TIMEOUT_MS
            );
            if (!resp.ok || !resp.body) {
              lastError = new Error(
                `stream ${resp.status} ${model}: ${(await resp.text()).slice(0, 300)}`
              );
              console.warn(lastError.message);
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
        if (upstream) break;
      }

      if (!upstream) {
        throw lastError || new Error("All streaming models failed");
      }

      res.status(200).set("Content-Type", "text/event-stream");
      const reader = upstream.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      let yielded = false;
      for (;;) {
        const { done, value } = await reader.read();
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
            yielded = true;
            res.write(`data: ${converted}\n\n`);
          }
        }
      }
      if (yielded) {
        await recordSuccessfulAIUse(uid);
      }
      res.end();
    } catch (e) {
      console.error("vertexProxy OpenRouter error:", e);
      if (!res.headersSent) {
        res.status(502).json({
          error: "upstream_failed",
          message: String(e?.message || e).slice(0, 500),
        });
      } else {
        res.end();
      }
    }
  }
);

// ==========================================
// 2) Auto-moderation of every new shared workout
// ==========================================
exports.moderateSharedWorkout = onDocumentCreated(
  {
    document: "shared_workouts/{workoutId}",
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    secrets: [openRouterApiKey],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const ref = snap.ref;

    const title = String(data.title || "").slice(0, 300);
    const description = String(data.description || "").slice(0, 2000);
    const exercises = Array.isArray(data.exercises)
      ? data.exercises.slice(0, 50)
      : [];
    const exerciseTexts = exercises
      .map((e) => {
        const name = String(e?.name || "").slice(0, 200);
        const notes = String(e?.notes || "").slice(0, 500);
        return notes ? `${name} — ${notes}` : name;
      })
      .filter(Boolean)
      .join("\n");

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

    const userPayload =
      `TITLE: ${title}\n` +
      `DESCRIPTION: ${description}\n` +
      `EXERCISES:\n${exerciseTexts}`;

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
      reason = "Moderation service error";
    }

    await ref.update({
      status: decision,
      moderationReason: reason,
      moderatedAt: FieldValue.serverTimestamp(),
    });

    console.log(
      `Moderated workout ${event.params.workoutId}: ${decision} — ${reason}`
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
            `Duplicate report ${event.params.reportId} ignored for workout ${workoutId} by uid=${reporterUid}`
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
exports.deleteAccount = onCall(
  {
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    enforceAppCheck: true,
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to delete your account."
      );
    }

    const db = getFirestore();

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

    return { ok: true };
  }
);

// Exported for local unit/smoke tests (not a Cloud Function).
module.exports._test = {
  geminiBodyToOpenAI,
  openAIToGeminiResponse,
  convertGeminiSchema,
  modelChainForRequest,
  parseApiKeys,
  stripModelJSON,
  hasImageContent,
  supportsResponseFormat,
  resolveReportUpdate,
  UPSTREAM_TIMEOUT_MS,
  FREE_MODELS_STRUCTURED,
  FREE_MODELS_FALLBACK,
  VISION_MODELS,
  callOpenRouterText,
};
