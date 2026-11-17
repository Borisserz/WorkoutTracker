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
