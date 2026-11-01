const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAppCheck } = require("firebase-admin/app-check");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const { defineSecret } = require("firebase-functions/params");

// Per-user AI rate limit (abuse control). With free OpenRouter models we still
// cap abuse, but count only successful upstream calls.
const AI_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_AI_WEEKLY_LIMIT = 200;

initializeApp();

// Stored in Secret Manager (not plain Cloud Run env). Comma-separate for key rotation.
const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");

const PROJECT_HINT = "serzhanovich-ecosystem-ce700";
const SERVICE_ACCOUNT =
  "firebase-adminsdk-fbsvc@serzhanovich-ecosystem-ce700.iam.gserviceaccount.com";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

// Structured-capable free models first, then broader free fallbacks.
const FREE_MODELS_STRUCTURED = [
  "xingchen-agi/xing4.0-29b-a4b:free",
  "liquid/lfm-2.5-2.6b:free",
  "dots-studio/dots-3-note-preview:free",
  "nvidia/nemotron-3.5-super-vl:free",
];
const FREE_MODELS_FALLBACK = [
  "google/gemma-4-26b-a4b-it:free",
  "recursive/flint-v1.0:free",
  "nvidia/nemotron-3.5-lightning:free",
  "google/gemma-4-31b-it:free",
];

const AUTO_BLOCK_REPORT_THRESHOLD = 3;

class RateLimitError extends Error {
  constructor(retryAfterSeconds, limit) {
    super("rate_limited");
    this.retryAfterSeconds = retryAfterSeconds;
    this.limit = limit;
  }
}

function parseApiKeys(raw) {
  return String(raw || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
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

function extractTextFromGeminiContents(contents) {
  if (!Array.isArray(contents)) return "";
  return contents
    .flatMap((c) => (Array.isArray(c.parts) ? c.parts : []))
    .map((p) => (typeof p?.text === "string" ? p.text : ""))
    .filter(Boolean)
    .join("\n");
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
      const text = Array.isArray(content.parts)
        ? content.parts.map((p) => p?.text).filter(Boolean).join("\n")
        : "";
      if (text) messages.push({ role, content: text });
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
  if (wantsJson) {
    const jsonSchema = convertGeminiSchema(gen.responseSchema);
    if (jsonSchema) {
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
  const wantsSchema = Boolean(body?.generationConfig?.responseSchema);
  if (wantsSchema) {
    return [...FREE_MODELS_STRUCTURED, ...FREE_MODELS_FALLBACK];
  }
  // Prefer fast Liquid for plain chat/stream, then the rest.
  return [
    "liquid/lfm-2.5-2.6b:free",
    ...FREE_MODELS_STRUCTURED.filter((m) => m !== "liquid/lfm-2.5-2.6b:free"),
    ...FREE_MODELS_FALLBACK,
  ];
}

async function openRouterFetch({ apiKeys, openAIBody, streaming }) {
  let lastError = null;

  for (const apiKey of apiKeys) {
    // Mutate model per attempt; keep a fresh copy of the body.
    const models = [openAIBody.model, ...(openAIBody.models || [])].filter(
      (m, i, arr) => m && arr.indexOf(m) === i
    );

    for (const model of models) {
      const attemptBody = { ...openAIBody, model };
      delete attemptBody.models;

      try {
        const resp = await fetch(OPENROUTER_URL, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${apiKey}`,
            "Content-Type": "application/json",
            "HTTP-Referer": `https://${PROJECT_HINT}.web.app`,
            "X-OpenRouter-Title": "WorkoutTracker",
          },
          body: JSON.stringify(attemptBody),
        });

        if (resp.status === 429 || resp.status >= 500) {
          const errText = await resp.text();
          lastError = new Error(
            `OpenRouter ${resp.status} model=${model}: ${errText.slice(0, 400)}`
          );
          console.warn(lastError.message);
          continue;
        }

        if (!resp.ok) {
          const errText = await resp.text();
          // Non-retryable for this model (e.g. 400 schema) — try next model.
          lastError = new Error(
            `OpenRouter ${resp.status} model=${model}: ${errText.slice(0, 400)}`
          );
          console.warn(lastError.message);
          continue;
        }

        return { resp, model, apiKeyIndex: apiKeys.indexOf(apiKey) };
      } catch (e) {
        lastError = e;
        console.warn("OpenRouter fetch failed:", e);
      }
    }
  }

  throw lastError || new Error("All OpenRouter models/keys failed");
}

async function callOpenRouterText({ apiKeys, geminiBody }) {
  const chain = modelChainForRequest(geminiBody);
  const openAIBody = geminiBodyToOpenAI(geminiBody, {
    streaming: false,
    model: chain[0],
  });
  openAIBody.models = chain.slice(1);

  // Manual fallback loop so we can strip json_schema on later attempts.
  let lastError = null;
  for (const apiKey of apiKeys) {
    for (let i = 0; i < chain.length; i++) {
      const model = chain[i];
      const attempt = geminiBodyToOpenAI(geminiBody, {
        streaming: false,
        model,
      });
      // After structured models fail, fall back to json_object.
      if (
        i >= FREE_MODELS_STRUCTURED.length &&
        attempt.response_format?.type === "json_schema"
      ) {
        attempt.response_format = { type: "json_object" };
      }

      const resp = await fetch(OPENROUTER_URL, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
          "HTTP-Referer": `https://${PROJECT_HINT}.web.app`,
          "X-OpenRouter-Title": "WorkoutTracker",
        },
        body: JSON.stringify(attempt),
      });
      const text = await resp.text();
      if (!resp.ok) {
        lastError = new Error(`OpenRouter ${resp.status} ${model}: ${text.slice(0, 400)}`);
        console.warn(lastError.message);
        continue;
      }
      let data;
      try {
        data = JSON.parse(text);
      } catch (e) {
        lastError = e;
        continue;
      }
      const expectJSON =
        geminiBody?.generationConfig?.responseMimeType === "application/json" ||
        Boolean(geminiBody?.generationConfig?.responseSchema);
      const gemini = openAIToGeminiResponse(data, { expectJSON });
      const outText = gemini.candidates?.[0]?.content?.parts?.[0]?.text || "";
      if (!outText) {
        lastError = new Error(`Empty completion from ${model}`);
        continue;
      }
      return gemini;
    }
  }
  throw lastError || new Error("OpenRouter text call failed");
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

      // Streaming: try models until one returns a live SSE body.
      let upstream = null;
      let lastError = null;
      for (const apiKey of apiKeys) {
        for (let i = 0; i < chain.length; i++) {
          const model = chain[i];
          const attempt = geminiBodyToOpenAI(body, { streaming: true, model });
          if (
            i >= FREE_MODELS_STRUCTURED.length &&
            attempt.response_format?.type === "json_schema"
          ) {
            attempt.response_format = { type: "json_object" };
          }
          const resp = await fetch(OPENROUTER_URL, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${apiKey}`,
              "Content-Type": "application/json",
              "HTTP-Referer": `https://${PROJECT_HINT}.web.app`,
              "X-OpenRouter-Title": "WorkoutTracker",
            },
            body: JSON.stringify(attempt),
          });
          if (!resp.ok || !resp.body) {
            lastError = new Error(
              `stream ${resp.status} ${model}: ${(await resp.text()).slice(0, 300)}`
            );
            console.warn(lastError.message);
            continue;
          }
          upstream = resp;
          break;
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
// 3) On every report — increment count + auto-block past threshold
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
    if (!workoutId || typeof workoutId !== "string") {
      console.warn("Report has no workoutId:", event.params.reportId);
      return;
    }

    const db = getFirestore();
    const workoutRef = db.collection("shared_workouts").doc(workoutId);

    try {
      await db.runTransaction(async (tx) => {
        const doc = await tx.get(workoutRef);
        if (!doc.exists) {
          console.warn(`Reported workout ${workoutId} does not exist`);
          return;
        }
        const current = doc.data() || {};
        const newCount = (current.reportCount || 0) + 1;
        const updates = { reportCount: newCount };
        if (
          newCount >= AUTO_BLOCK_REPORT_THRESHOLD &&
          current.status !== "blocked"
        ) {
          updates.status = "blocked";
          updates.moderationReason = `Auto-blocked after ${newCount} user reports`;
          updates.moderatedAt = FieldValue.serverTimestamp();
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

    const reportsSnap = await db
      .collection("reports")
      .where("reporterUid", "==", uid)
      .get();

    const refs = [
      ...sharedSnap.docs.map((d) => d.ref),
      ...reportsSnap.docs.map((d) => d.ref),
    ];
    for (let i = 0; i < refs.length; i += 450) {
      const batch = db.batch();
      refs.slice(i, i + 450).forEach((ref) => batch.delete(ref));
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
  FREE_MODELS_STRUCTURED,
  FREE_MODELS_FALLBACK,
  callOpenRouterText,
};
