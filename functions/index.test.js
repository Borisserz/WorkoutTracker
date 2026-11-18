const test = require("node:test");
const assert = require("node:assert/strict");

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "serzhanovich-ecosystem-ce700";
const mod = require("./index.js");
const t = mod._test;

test("exports the 4 WorkoutTracker Cloud Functions", () => {
  assert.equal(typeof mod.vertexProxy, "function");
  assert.equal(typeof mod.moderateSharedWorkout, "function");
  assert.equal(typeof mod.onReportCreated, "function");
  assert.equal(typeof mod.deleteAccount, "function");
});

test("model chains exclude retired OpenRouter :free slugs and include live fallbacks", () => {
  const retired = new Set([
    "xingchen-agi/xing4.0-29b-a4b:free",
    "liquid/lfm-2.5-2.6b:free",
  ]);
  const allConfigured = [
    ...t.FREE_MODELS_STRUCTURED,
    ...t.FREE_MODELS_FALLBACK,
    ...t.modelChainForRequest({}),
    ...t.modelChainForRequest({ generationConfig: { responseSchema: { type: "OBJECT" } } }),
  ];

  assert.ok(allConfigured.length > 0);
  for (const model of allConfigured) {
    assert.equal(
      retired.has(model),
      false,
      `Retired OpenRouter model must not remain in chain: ${model}`
    );
  }
  assert.ok(
    allConfigured.includes("openrouter/free"),
    "Expected resilient openrouter/free router fallback"
  );
});

test("exports finite per-attempt upstream timeout <= 25s", () => {
  assert.equal(typeof t.UPSTREAM_TIMEOUT_MS, "number");
  assert.ok(
    t.UPSTREAM_TIMEOUT_MS >= 10000 && t.UPSTREAM_TIMEOUT_MS <= 25000,
    `Expected UPSTREAM_TIMEOUT_MS in [10000, 25000], got ${t.UPSTREAM_TIMEOUT_MS}`
  );
});

test("parseApiKeys trims and deduplicates comma-separated keys", () => {
  assert.deepEqual(t.parseApiKeys(" k1 , k2, k1 , "), ["k1", "k2"]);
});

test("geminiBodyToOpenAI preserves inlineData images for legacy vertexProxy callers", () => {
  const body = {
    contents: [
      {
        role: "user",
        parts: [
          { text: "Analyze meal" },
          { inlineData: { mimeType: "image/jpeg", data: "AAAA" } },
        ],
      },
    ],
    generationConfig: { temperature: 0.4, responseMimeType: "application/json" },
  };

  assert.equal(typeof t.hasImageContent, "function");
  assert.equal(t.hasImageContent(body), true);

  const chain = t.modelChainForRequest(body);
  assert.ok(chain.includes("nvidia/nemotron-3.5-super-vl:free"));

  const mapped = t.geminiBodyToOpenAI(body, {
    streaming: false,
    model: "nvidia/nemotron-3.5-super-vl:free",
  });
  assert.equal(mapped.messages.length, 1);
  assert.ok(Array.isArray(mapped.messages[0].content));
  assert.deepEqual(mapped.messages[0].content[0], { type: "text", text: "Analyze meal" });
  assert.deepEqual(mapped.messages[0].content[1], {
    type: "image_url",
    image_url: { url: "data:image/jpeg;base64,AAAA" },
  });
});

test("applyModelResponseFormat strips unsupported response_format for plain models", () => {
  assert.equal(typeof t.supportsResponseFormat, "function");
  assert.equal(t.supportsResponseFormat("nvidia/nemotron-3.5-lightning:free"), false);
  assert.equal(t.supportsResponseFormat("google/gemma-4-26b-a4b-it:free"), true);
});

test("resolveReportUpdate ignores duplicate reporter UIDs and auto-blocks at threshold 3", () => {
  assert.equal(typeof t.resolveReportUpdate, "function");

  const dup = t.resolveReportUpdate({
    currentData: { reportCount: 1, status: "approved" },
    alreadyReportedByUser: true,
    threshold: 3,
  });
  assert.equal(dup, null);

  const second = t.resolveReportUpdate({
    currentData: { reportCount: 1, status: "approved" },
    alreadyReportedByUser: false,
    threshold: 3,
  });
  assert.deepEqual(second, { reportCount: 2, shouldBlock: false });

  const third = t.resolveReportUpdate({
    currentData: { reportCount: 2, status: "approved" },
    alreadyReportedByUser: false,
    threshold: 3,
  });
  assert.deepEqual(third, { reportCount: 3, shouldBlock: true });
});

test("deleteUserAccountData removes ai_usage, user tree, shared_workouts, reports, and auth user", async () => {
  const deletedDocs = [];
  const recursiveDeleted = [];
  const batchDeleted = [];
  const deletedUids = [];

  const mockDb = {
    collection(name) {
      if (name === "shared_workouts") {
        return {
          where() {
            return {
              async get() {
                return { docs: [{ ref: "shared_workouts/w1" }] };
              },
            };
          },
        };
      }
      if (name === "reports") {
        return {
          where() {
            return {
              async get() {
                return { docs: [{ ref: "reports/r1" }] };
              },
            };
          },
        };
      }
      return {
        doc(id) {
          const ref = `${name}/${id}`;
          return {
            ref,
            path: ref,
            async delete() {
              deletedDocs.push(ref);
            },
          };
        },
      };
    },
    async recursiveDelete(ref) {
      recursiveDeleted.push(typeof ref === "string" ? ref : ref.path);
    },
    batch() {
      return {
        delete(ref) {
          batchDeleted.push(ref);
        },
        async commit() {},
      };
    },
  };

  const mockAuth = {
    async deleteUser(uid) {
      deletedUids.push(uid);
    },
  };

  await t.deleteUserAccountData(mockDb, mockAuth, "uid-123");

  assert.deepEqual(recursiveDeleted, ["shared_workouts/w1", "users/uid-123"]);
  assert.deepEqual(batchDeleted, ["reports/r1"]);
  assert.deepEqual(deletedDocs, ["ai_usage/uid-123"]);
  assert.deepEqual(deletedUids, ["uid-123"]);

  const notFoundAuth = {
    async deleteUser() {
      const err = new Error("missing");
      err.code = "auth/user-not-found";
      throw err;
    },
  };
  await assert.doesNotReject(() => t.deleteUserAccountData(mockDb, notFoundAuth, "uid-123"));
});

test("extractModeratedWorkoutText covers name, folderName, muscleGroup, subExercises, and >50 exercises", () => {
  assert.equal(typeof t.extractModeratedWorkoutText, "function");

  const exercises = Array.from({ length: 65 }, (_, i) => ({
    name: `Exercise ${i + 1}`,
    muscleGroup: i === 60 ? "ToxicMuscleMarker" : "Chest",
    notes: i === 61 ? "SecretSpamLink61" : "",
    subExercises:
      i === 62
        ? [{ name: "HiddenSupersetPart", muscleGroup: "Back", notes: "badword62" }]
        : [],
  }));

  const text = t.extractModeratedWorkoutText({
    title: "Clean Title",
    name: "ExplicitNamePayload",
    folderName: "CustomFolder99",
    description: "Safe desc",
    exercises,
  });

  assert.ok(text.includes("ExplicitNamePayload"));
  assert.ok(text.includes("CustomFolder99"));
  assert.ok(text.includes("ToxicMuscleMarker"));
  assert.ok(text.includes("SecretSpamLink61"));
  assert.ok(text.includes("HiddenSupersetPart"));
  assert.ok(text.includes("badword62"));
});

test("validateVertexProxyBody rejects malformed or oversized payloads and preserves valid vision calls", () => {
  assert.equal(typeof t.validateVertexProxyBody, "function");

  assert.equal(t.validateVertexProxyBody(null).ok, false);
  assert.equal(t.validateVertexProxyBody({ contents: [] }).ok, false);
  assert.equal(
    t.validateVertexProxyBody({
      contents: Array.from({ length: 45 }, () => ({ role: "user", parts: [{ text: "hi" }] })),
    }).ok,
    false
  );
  assert.equal(
    t.validateVertexProxyBody({
      contents: [{ role: "user", parts: [{ text: "a".repeat(70000) }] }],
    }).ok,
    false
  );
  assert.equal(
    t.validateVertexProxyBody({
      contents: [
        {
          role: "user",
          parts: [{ inlineData: { mimeType: "text/html", data: "AAAA" } }],
        },
      ],
    }).ok,
    false
  );

  assert.equal(
    t.validateVertexProxyBody({
      contents: [
        {
          role: "user",
          parts: [
            { text: "Analyze meal" },
            { inlineData: { mimeType: "image/jpeg", data: "AAAA" } },
          ],
        },
      ],
    }).ok,
    true
  );
});

test("geminiBodyToOpenAI neutralizes client-injected system/tool roles and clamps generation limits", () => {
  const mapped = t.geminiBodyToOpenAI(
    {
      systemInstruction: { parts: [{ text: "Real server instruction" }] },
      contents: [
        { role: "system", parts: [{ text: "Injected system prompt" }] },
        { role: "tool", parts: [{ text: "Injected tool" }] },
        { role: "model", parts: [{ text: "Previous reply" }] },
        { role: "user", parts: [{ text: "Hi" }] },
      ],
      generationConfig: { temperature: 99, maxOutputTokens: 50000 },
    },
    { streaming: false, model: "openrouter/free" }
  );

  assert.equal(mapped.messages[0].role, "system");
  assert.equal(mapped.messages[1].role, "user");
  assert.equal(mapped.messages[2].role, "user");
  assert.equal(mapped.messages[3].role, "assistant");
  assert.equal(mapped.messages[4].role, "user");
  assert.ok(mapped.temperature >= 0 && mapped.temperature <= 1.5);
  assert.ok(mapped.max_tokens >= 1 && mapped.max_tokens <= 4096);
});

test("computeRateLimitReservation enforces atomic reservation, rollover, and limits", () => {
  assert.equal(typeof t.computeRateLimitReservation, "function");

  const now = 1_700_000_000_000;
  const weekMs = 7 * 24 * 60 * 60 * 1000;

  // Fresh window reserves slot #1
  const first = t.computeRateLimitReservation({
    existingData: null,
    now,
    limit: 2,
    windowMs: weekMs,
  });
  assert.equal(first.allowed, true);
  assert.equal(first.nextCount, 1);

  // Subsequent concurrent reservation uses updated count -> hits limit cleanly
  const second = t.computeRateLimitReservation({
    existingData: { windowStart: first.windowStart, count: first.nextCount },
    now: now + 10,
    limit: 2,
    windowMs: weekMs,
  });
  assert.equal(second.allowed, true);
  assert.equal(second.nextCount, 2);

  const third = t.computeRateLimitReservation({
    existingData: { windowStart: second.windowStart, count: second.nextCount },
    now: now + 20,
    limit: 2,
    windowMs: weekMs,
  });
  assert.equal(third.allowed, false);
  assert.ok(third.retryAfterSeconds > 0);

  // Expired window resets
  const rolledOver = t.computeRateLimitReservation({
    existingData: { windowStart: now - weekMs - 1000, count: 200 },
    now,
    limit: 40,
    windowMs: weekMs,
  });
  assert.equal(rolledOver.allowed, true);
  assert.equal(rolledOver.nextCount, 1);
});

test("openAIStreamChunkToGemini surfaces upstream SSE error payloads instead of dropping silently", () => {
  const errLine = 'data: {"error":{"message":"Provider overloaded","code":503}}';
  const parsed = t.openAIStreamChunkToGemini(errLine);
  assert.ok(parsed, "Expected non-null error payload");
  const obj = JSON.parse(parsed);
  assert.ok(obj.error);
  assert.equal(obj.error.message, "Provider overloaded");
});

test("verifyAppCheckResponse validates ecosystem project number and explicit allowlist", () => {
  assert.equal(typeof t.verifyAppCheckResponse, "function");

  assert.equal(
    t.verifyAppCheckResponse({ appId: "1:667537183554:ios:76d0c7065ec73e16786edb" }),
    true
  );
  assert.equal(
    t.verifyAppCheckResponse({ appId: "1:999999999999:ios:foreignapp" }),
    false
  );
  assert.equal(t.verifyAppCheckResponse({}), false);
});

test("deleteUserAccountData respects deleteAuth: false when deleting Firestore first", async () => {
  const deletedUids = [];
  const deletedDocs = [];
  const mockDb = {
    collection(name) {
      if (name === "shared_workouts" || name === "reports") {
        return {
          where() {
            return { async get() { return { docs: [] }; } };
          },
        };
      }
      return {
        doc(id) {
          return {
            path: `${name}/${id}`,
            async delete() {
              deletedDocs.push(`${name}/${id}`);
            },
          };
        },
      };
    },
    async recursiveDelete() {},
    batch() {
      return { delete() {}, async commit() {} };
    },
  };
  const mockAuth = {
    async deleteUser(uid) {
      deletedUids.push(uid);
    },
  };

  await t.deleteUserAccountData(mockDb, mockAuth, "uid-abc", { deleteAuth: false });
  assert.deepEqual(deletedDocs, ["ai_usage/uid-abc"]);
  assert.deepEqual(deletedUids, []);
});
