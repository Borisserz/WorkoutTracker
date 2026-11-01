#!/usr/bin/env node
/**
 * Local smoke test for OpenRouter translation + free-model fallback + feature shapes.
 * Does NOT hit Firebase App Check. Reads key from OPENROUTER_API_KEY or .secret.local / .env.
 */
const fs = require("fs");
const path = require("path");

function loadKey() {
  if (process.env.OPENROUTER_API_KEY) return process.env.OPENROUTER_API_KEY.trim();
  for (const file of [".env", ".secret.local"]) {
    const secretPath = path.join(__dirname, file);
    if (!fs.existsSync(secretPath)) continue;
    const raw = fs.readFileSync(secretPath, "utf8");
    const line = raw.split("\n").find((l) => l.startsWith("OPENROUTER_API_KEY="));
    if (line) return line.slice("OPENROUTER_API_KEY=".length).trim();
  }
  throw new Error("No OPENROUTER_API_KEY found");
}

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "serzhanovich-ecosystem-ce700";
const mod = require("./index.js");
const {
  geminiBodyToOpenAI,
  openAIToGeminiResponse,
  callOpenRouterText,
  parseApiKeys,
  modelChainForRequest,
} = mod._test;

async function callJSON(apiKeys, system, user, schema) {
  const geminiBody = {
    systemInstruction: { parts: [{ text: system }] },
    contents: [{ role: "user", parts: [{ text: user }] }],
    generationConfig: {
      temperature: 0.2,
      responseMimeType: "application/json",
      responseSchema: schema,
    },
  };
  const gemini = await callOpenRouterText({ apiKeys, geminiBody });
  const text = gemini.candidates[0].content.parts[0].text;
  const parsed = JSON.parse(text);
  return { text, parsed };
}

async function main() {
  const apiKeys = parseApiKeys(loadKey());
  console.log("keys loaded:", apiKeys.length);

  // --- helpers ---
  const fenced = openAIToGeminiResponse(
    { choices: [{ message: { content: '```json\n{"a":1}\n```' } }] },
    { expectJSON: true }
  );
  const fencedText = fenced.candidates[0].content.parts[0].text;
  if (fencedText !== '{"a":1}') {
    throw new Error(`strip failed: ${fencedText}`);
  }
  console.log("OK server JSON strip");

  // --- plain chat ---
  console.log("\n--- plain chat ---");
  const plain = await callOpenRouterText({
    apiKeys,
    geminiBody: {
      systemInstruction: {
        parts: [{ text: "You are a concise fitness coach. One short sentence. No JSON." }],
      },
      contents: [{ role: "user", parts: [{ text: "Give one squat cue." }] }],
      generationConfig: { temperature: 0.2, responseMimeType: "text/plain", responseSchema: null },
    },
  });
  console.log("OK plain:", plain.candidates[0].content.parts[0].text.slice(0, 160));

  // --- builder shape ---
  console.log("\n--- builder workout JSON ---");
  const builderSchema = {
    type: "OBJECT",
    properties: {
      aiMessage: { type: "STRING" },
      workoutTitle: { type: "STRING" },
      exercises: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            name: { type: "STRING" },
            muscleGroup: { type: "STRING" },
            type: { type: "STRING" },
            sets: { type: "INTEGER" },
            reps: { type: "INTEGER" },
            recommendedWeightKg: { type: "NUMBER" },
            restSeconds: { type: "INTEGER" },
          },
          required: ["name", "muscleGroup", "type", "sets", "reps"],
        },
      },
    },
    required: ["aiMessage", "workoutTitle", "exercises"],
  };
  const builder = await callJSON(
    apiKeys,
    `Return ONE JSON object only. Generate EXACTLY 4 exercises from: Bench Press, Incline Dumbbell Press, Cable Fly, Tricep Pushdown, Push-up.
workoutTitle must be "Protocol: Chest". Do not invent names.`,
    "Generate a Chest workout at Intermediate level.",
    builderSchema
  );
  if (!Array.isArray(builder.parsed.exercises) || builder.parsed.exercises.length < 4) {
    throw new Error(`builder exercises bad: ${builder.text.slice(0, 300)}`);
  }
  console.log("OK builder exercises:", builder.parsed.exercises.length, builder.parsed.workoutTitle);

  // --- smart action ---
  console.log("\n--- smart action JSON ---");
  const smart = await callJSON(
    apiKeys,
    `Return ONE JSON only. action must be one of: swap|reduce_weight|increase_weight|add_finisher.
Fields: action, exerciseName, setsRemaining, weightValue, reasoning.`,
    "Current workout:\nBench Press 80kg 3x5\nUser command: Too Heavy",
    {
      type: "OBJECT",
      properties: {
        action: { type: "STRING" },
        exerciseName: { type: "STRING" },
        setsRemaining: { type: "INTEGER" },
        weightValue: { type: "NUMBER" },
        reasoning: { type: "STRING" },
      },
      required: ["action", "exerciseName", "setsRemaining", "weightValue", "reasoning"],
    }
  );
  const allowed = new Set(["swap", "reduce_weight", "increase_weight", "add_finisher"]);
  if (!allowed.has(smart.parsed.action)) {
    throw new Error(`smart action invalid: ${smart.parsed.action}`);
  }
  console.log("OK smart:", smart.parsed.action, smart.parsed.weightValue);

  // --- weekly review ---
  console.log("\n--- weekly review JSON ---");
  const weekly = await callJSON(
    apiKeys,
    `Return ONE JSON only with weeklyScore, title, topHighlight, weakPointAlert, coachAdvice, coachMood (fire|ice|warning).`,
    "My stats:\nWorkouts: 4\nVolume: up 12%\nSkipped legs once",
    {
      type: "OBJECT",
      properties: {
        weeklyScore: { type: "INTEGER" },
        title: { type: "STRING" },
        topHighlight: { type: "STRING" },
        weakPointAlert: { type: "STRING" },
        coachAdvice: { type: "STRING" },
        coachMood: { type: "STRING" },
      },
      required: ["weeklyScore", "title", "topHighlight", "weakPointAlert", "coachAdvice", "coachMood"],
    }
  );
  if (typeof weekly.parsed.weeklyScore !== "number") {
    throw new Error("weeklyScore missing");
  }
  console.log("OK weekly:", weekly.parsed.weeklyScore, weekly.parsed.coachMood);

  // --- moderation ---
  console.log("\n--- moderation JSON ---");
  const modResult = await callJSON(
    apiKeys,
    'Respond ONLY JSON {"decision":"approved"|"blocked","reason":"..."}.',
    "TITLE: Leg Day\nDESCRIPTION: Squats and RDLs\nEXERCISES:\nBack Squat\nRomanian Deadlift",
    {
      type: "OBJECT",
      properties: {
        decision: { type: "STRING" },
        reason: { type: "STRING" },
      },
      required: ["decision", "reason"],
    }
  );
  if (!["approved", "blocked"].includes(modResult.parsed.decision)) {
    throw new Error(`moderation decision bad: ${modResult.parsed.decision}`);
  }
  console.log("OK moderation:", modResult.parsed.decision);

  // mapping sanity
  const mapped = geminiBodyToOpenAI(
    {
      systemInstruction: { parts: [{ text: "sys" }] },
      contents: [{ role: "user", parts: [{ text: "hi" }] }],
      generationConfig: { temperature: 0.1, responseMimeType: "text/plain" },
    },
    { streaming: false, model: modelChainForRequest({})[0] }
  );
  if (mapped.messages.length !== 2) throw new Error("message map failed");

  console.log("\nAll smoke checks passed.");
}

main().catch((e) => {
  console.error("SMOKE FAILED:", e);
  process.exit(1);
});
