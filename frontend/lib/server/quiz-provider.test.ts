import { test } from "node:test";
import assert from "node:assert/strict";
// @ts-ignore Node's native test runner uses explicit TypeScript extensions.
import { OpenRouterError, type GenerateOptions } from "./openrouter.ts";
// @ts-ignore Node's native test runner uses explicit TypeScript extensions.
import { quizGenerator } from "./quiz-provider.ts";

const options: GenerateOptions = {
  systemInstruction: "Source-only questions",
  prompt: "Source",
  temperature: 0.2,
  maxOutputTokens: 5400,
  reasoningEffort: "none",
  responseJsonSchema: { type: "object" },
  signal: AbortSignal.timeout(10000),
};
test("an unavailable quiz endpoint switches once and remembers the fallback for content repair", async () => {
  const calls: GenerateOptions[] = [];
  const generate = quizGenerator(
    async (request) => {
      calls.push(request);
      if (request.model === "primary") throw new OpenRouterError(404);
      return { text: "{}", model: request.model! };
    },
    "primary",
    "cohere/north-mini-code:free",
  );
  await generate(options);
  await generate(options);
  assert.deepEqual(
    calls.map((c) => c.model),
    ["primary", "cohere/north-mini-code:free", "cohere/north-mini-code:free"],
  );
  assert.equal(calls[0].jsonResponse, true);
  assert.equal(calls[1].jsonResponse, false);
  assert.equal(calls[1].signal, options.signal);
  assert.equal(calls[1].responseJsonSchema, options.responseJsonSchema);
});
test("authentication, malformed content and cancellation never trigger provider fallback", async () => {
  for (const error of [
    new OpenRouterError(401),
    new OpenRouterError(403),
    new Error("No source-supported quiz questions returned"),
  ]) {
    let calls = 0;
    const generate = quizGenerator(
      async () => {
        calls++;
        throw error;
      },
      "primary",
      "fallback",
    );
    await assert.rejects(generate(options), error);
    assert.equal(calls, 1);
  }
  let calls = 0;
  const generate = quizGenerator(
    async () => {
      calls++;
      throw new OpenRouterError(404);
    },
    "primary",
    "fallback",
  );
  await assert.rejects(generate({ ...options, signal: AbortSignal.abort() }));
  assert.equal(calls, 1);
});
