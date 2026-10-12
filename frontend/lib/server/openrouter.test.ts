import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
// Run with node --experimental-strip-types --test lib/server/openrouter.test.ts
// @ts-ignore Node's native test runner needs the .ts extension.
import { generateOpenRouterText } from "./openrouter.ts";

const originalFetch = globalThis.fetch;
const envNames = ["OPENROUTER_API_KEY", "OPENROUTER_MODEL", "OPENROUTER_ZDR"];
const originalEnv = envNames.map(name => process.env[name]);
const options = { systemInstruction: "Answer safely", prompt: "Test source", temperature: 0.2, maxOutputTokens: 2048 };

afterEach(() => {
  globalThis.fetch = originalFetch;
  envNames.forEach((name, index) => {
    if (originalEnv[index] === undefined) delete process.env[name];
    else process.env[name] = originalEnv[index];
  });
});

test("sends JSON generation to OpenRouter with privacy routing and real model attribution", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  process.env.OPENROUTER_MODEL = " test/model ";
  process.env.OPENROUTER_ZDR = "true";
  globalThis.fetch = async (input, init) => {
    assert.equal(input, "https://openrouter.ai/api/v1/chat/completions");
    assert.equal((init?.headers as Record<string, string>).Authorization, "Bearer test-key");
    const body = JSON.parse(String(init?.body));
    assert.equal(body.model, "test/model");
    assert.equal(body.max_tokens, 2048);
    assert.deepEqual(body.provider, { data_collection: "deny", zdr: true, require_parameters: true });
    assert.deepEqual(body.response_format, { type: "json_object" });
    assert.match(body.messages[0].content, /Return JSON only/);
    assert.equal(body.messages[1].content, "Test source");
    return Response.json({ model: "actual/model", choices: [{ message: { content: '{"summary":"Ready","entities":[]}' } }] });
  };
  const result = await generateOpenRouterText({ ...options, responseJsonSchema: { type: "object" } });
  assert.equal(result.model, "actual/model");
  assert.equal(JSON.parse(result.text).summary, "Ready");
});

test("defaults to the free router without forcing zero-retention endpoints", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  delete process.env.OPENROUTER_MODEL;
  delete process.env.OPENROUTER_ZDR;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body));
    assert.equal(body.model, "openrouter/free");
    assert.deepEqual(body.provider, { data_collection: "deny" });
    assert.equal(body.response_format, undefined);
    return Response.json({ choices: [{ message: { content: " Answer [SOURCE:1] " } }] });
  };
  assert.deepEqual(await generateOpenRouterText(options), { text: "Answer [SOURCE:1]", model: "openrouter/free" });
});

test("retries transient failures with the same request", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  let calls = 0;
  let firstBody: unknown;
  globalThis.fetch = async (_input, init) => {
    calls++;
    if (calls === 1) firstBody = init?.body;
    assert.equal(init?.body, firstBody);
    return calls < 3 ? new Response("busy", { status: 503, headers: { "retry-after": "0" } })
      : Response.json({ choices: [{ message: { content: "Recovered" } }] });
  };
  assert.equal((await generateOpenRouterText(options)).text, "Recovered");
  assert.equal(calls, 3);
});

test("does not retry authentication errors or expose submitted content", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  let calls = 0;
  globalThis.fetch = async () => { calls++; return new Response("private document text", { status: 401 }); };
  await assert.rejects(generateOpenRouterText(options), { message: "OpenRouter request failed (401)" });
  assert.equal(calls, 1);
});

test("rejects missing keys before any provider request", async () => {
  process.env.OPENROUTER_API_KEY = " ";
  globalThis.fetch = async () => { assert.fail("Must not call provider"); };
  await assert.rejects(generateOpenRouterText(options), { message: "OpenRouter is not configured yet" });
});

test("rejects empty, truncated and embedded-error responses", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  for (const payload of [
    { choices: [{ message: { content: "" } }] },
    { choices: [{ message: { content: "Partial" }, finish_reason: "length" }] },
    { error: { message: "private document text" }, choices: [{ message: { content: "Partial" } }] },
  ]) {
    globalThis.fetch = async () => Response.json(payload);
    await assert.rejects(generateOpenRouterText(options), { message: "OpenRouter returned no complete usable response" });
  }
});

test("stops retrying when the request timeout aborts", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  const controller = new AbortController();
  let calls = 0;
  globalThis.fetch = async () => { calls++; controller.abort(new Error("Timed out")); throw controller.signal.reason; };
  await assert.rejects(generateOpenRouterText({ ...options, signal: controller.signal }), { message: "Timed out" });
  assert.equal(calls, 1);
});
