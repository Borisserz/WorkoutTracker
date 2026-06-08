const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getAppCheck } = require("firebase-admin/app-check");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { GoogleAuth } = require("google-auth-library");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
// Per-user AI rate limit (abuse / cost control for the paid Vertex proxy).
const AI_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;     // 7 days in ms
const DEFAULT_AI_WEEKLY_LIMIT = 10;               // default requests per rolling 7-day window
initializeApp();

// ==========================================
// Configuration
// ==========================================
const PROJECT_ID = "serzhanovich-ecosystem-ce700";
const LOCATION = "us-central1";
const MODEL = "gemini-3.5-flash";
const AUTO_BLOCK_REPORT_THRESHOLD = 3;
const SERVICE_ACCOUNT =
  "firebase-adminsdk-fbsvc@serzhanovich-ecosystem-ce700.iam.gserviceaccount.com";

const auth = new GoogleAuth({
  scopes: "https://www.googleapis.com/auth/cloud-platform",
});

// Safety thresholds for user-facing Vertex traffic.
// Closes App Review [1.1]: server forces these, client cannot bypass.
const SAFETY_SETTINGS_USER = [
  { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
  { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
  { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_LOW_AND_ABOVE" },
  { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
];

// For the moderator pass we want Gemini to SEE flagged input so it can classify it.
const SAFETY_SETTINGS_MODERATOR = [
  { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
];

async function vertexFetch(body) {
  const client = await auth.getClient();
  const accessToken = (await client.getAccessToken()).token;
  const url =
    `https://aiplatform.googleapis.com/v1/projects/${PROJECT_ID}` +
    `/locations/global/publishers/google/models/${MODEL}:generateContent`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(`Vertex error ${resp.status}: ${text}`);
  }
  return JSON.parse(text);
}
class RateLimitError extends Error {
  constructor(retryAfterSeconds, limit) {
    super("rate_limited");
    this.retryAfterSeconds = retryAfterSeconds;
    this.limit = limit;
  }
}

// Atomically enforces a rolling 7-day per-user limit on AI proxy calls.
// Counts on entry (so aborted/failed calls still count — abuse-resistant).
async function enforceRateLimit(uid) {
  const db = getFirestore();
  
  // Fetch current global limit from Firestore (config/ai_settings)
  const configSnap = await db.collection("config").doc("ai_settings").get();
  const configData = configSnap.data() || {};
  const aiWeeklyLimit = typeof configData.weeklyLimit === "number" ? configData.weeklyLimit : DEFAULT_AI_WEEKLY_LIMIT;

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
        windowStart = ws;          // still inside the current 7-day window
        count = data.count || 0;
      }
      // else: window expired → reset (windowStart = now, count = 0)
    }

    if (count >= aiWeeklyLimit) {
      const retryAfterSeconds = Math.ceil((windowStart + AI_WINDOW_MS - now) / 1000);
      throw new RateLimitError(retryAfterSeconds, aiWeeklyLimit);
    }

    tx.set(ref, {
      windowStart,
      count: count + 1,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });
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
  },
  async (req, res) => {
    // App Check verification
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
// --- Per-user auth (needed for rate limiting) ---
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

// --- Per-user weekly rate limit ---
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
    // Force server-side safety settings (the client cannot override them).
    const body = req.body || {};
    body.safetySettings = SAFETY_SETTINGS_USER;

    // Get a fresh access token from the function's runtime service account.
    const client = await auth.getClient();
    const accessToken = (await client.getAccessToken()).token;

    const streaming = req.query.stream === "true";
    const method = streaming ? "streamGenerateContent" : "generateContent";
    const sse = streaming ? "?alt=sse" : "";
    const url =
      `https://aiplatform.googleapis.com/v1/projects/${PROJECT_ID}` +
      `/locations/global/publishers/google/models/${MODEL}:${method}${sse}`;

    const upstream = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!streaming) {
      const data = await upstream.text();
      res
        .status(upstream.status)
        .set("Content-Type", "application/json")
        .send(data);
      return;
    }

    res.status(upstream.status).set("Content-Type", "text/event-stream");
    const reader = upstream.body.getReader();
    const decoder = new TextDecoder();
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      res.write(decoder.decode(value, { stream: true }));
    }
    res.end();
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
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const ref = snap.ref;

    const title = String(data.title || "").slice(0, 300);
    const description = String(data.description || "").slice(0, 2000);
    const exercises = Array.isArray(data.exercises) ? data.exercises.slice(0, 50) : [];
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
      const body = {
        systemInstruction: { parts: [{ text: systemPrompt }] },
        contents: [{ role: "user", parts: [{ text: userPayload }] }],
        generationConfig: {
          temperature: 0.0,
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: {
              decision: { type: "string", enum: ["approved", "blocked"] },
              reason: { type: "string" },
            },
            required: ["decision", "reason"],
          },
        },
        safetySettings: SAFETY_SETTINGS_MODERATOR,
      };
      const resp = await vertexFetch(body);
      const text = resp?.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
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
//    Deletes ALL server-side data tied to the caller's uid,
//    then the Auth account is removed by the client.
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

    // 1) shared_workouts created by this user (creatorUid == uid)
    const sharedSnap = await db
      .collection("shared_workouts")
      .where("creatorUid", "==", uid)
      .get();

    // 2) reports filed by this user (reporterUid == uid)
    const reportsSnap = await db
      .collection("reports")
      .where("reporterUid", "==", uid)
      .get();

    // Batched delete (chunks of 500 — Firestore batch limit)
    const refs = [
      ...sharedSnap.docs.map((d) => d.ref),
      ...reportsSnap.docs.map((d) => d.ref),
    ];
    for (let i = 0; i < refs.length; i += 450) {
      const batch = db.batch();
      refs.slice(i, i + 450).forEach((ref) => batch.delete(ref));
      await batch.commit();
    }

    // 3) users/{uid} doc + all subcollections (incl. blocked/*)
    await db.recursiveDelete(db.collection("users").doc(uid));

    // NOTE: we intentionally do NOT call getAuth().deleteUser(uid) here.
    // The client calls Auth.auth().currentUser?.delete() right after this
    // resolves, per the required flow. (If you prefer server-side auth
    // deletion instead, uncomment the next line and have the client just
    // sign out.)
    // await getAuth().deleteUser(uid);

    return { ok: true };
  }
);