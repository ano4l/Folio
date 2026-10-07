import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
// Run with node --experimental-strip-types --test lib/server/gemini.test.ts
// @ts-ignore Node's native test runner needs the .ts extension.
import { generateGeminiText } from "./gemini.ts";

const originalFetch = globalThis.fetch;
const originalKey = process.env.GEMINI_API_KEY;
const originalModel = process.env.GEMINI_MODEL;

afterEach(() => {
  globalThis.fetch = originalFetch;
  if (originalKey === undefined) delete process.env.GEMINI_API_KEY;
  else process.env.GEMINI_API_KEY = originalKey;
  if (originalModel === undefined) delete process.env.GEMINI_MODEL;
  else process.env.GEMINI_MODEL = originalModel;
});

test("uses the current Gemini 3 structured-output and thinking contract", async () => {
  process.env.GEMINI_API_KEY = "test-key";
  process.env.GEMINI_MODEL = "gemini-test";
  let requestBody: Record<string, any> = {};
  globalThis.fetch = async (_input, init) => {
    requestBody = JSON.parse(String(init?.body));
    return Response.json({ modelVersion: "gemini-test-001", candidates: [{ content: { parts: [{ text: "{\"summary\":\"Ready\",\"entities\":[]}" }] } }] });
  };

  const result = await generateGeminiText({
    systemInstruction: "Summarise safely",
    prompt: "Test document",
    temperature: 0.1,
    maxOutputTokens: 2048,
    responseJsonSchema: { type: "object" },
  });

  assert.equal(requestBody.generationConfig.thinkingConfig.thinkingLevel, "LOW");
  assert.equal(requestBody.generationConfig.responseFormat.text.mimeType, "APPLICATION_JSON");
  assert.deepEqual(requestBody.generationConfig.responseFormat.text.schema, { type: "object" });
  assert.equal(requestBody.generationConfig.responseJsonSchema, undefined);
  assert.equal(result.model, "gemini-test-001");
});

test("joins multipart Gemini text into one usable response", async () => {
  process.env.GEMINI_API_KEY = "test-key";
  delete process.env.GEMINI_MODEL;
  globalThis.fetch = async () => Response.json({ candidates: [{ content: { parts: [{ text: "First" }, { text: " second" }] } }] });

  const result = await generateGeminiText({ systemInstruction: "Answer", prompt: "Question", temperature: 0.2, maxOutputTokens: 2048 });

  assert.equal(result.text, "First second");
  assert.equal(result.model, "gemini-3.8-flash");
});

test("fails safely on provider rejection without exposing the response body", async () => {
  process.env.GEMINI_API_KEY = "test-key";
  globalThis.fetch = async () => new Response("private submitted document text", { status: 429 });

  await assert.rejects(
    generateGeminiText({ systemInstruction: "Answer", prompt: "Private text", temperature: 0.2, maxOutputTokens: 2048 }),
    error => error instanceof Error && error.message === "Gemini request failed (429)" && !error.message.includes("private"),
  );
});
