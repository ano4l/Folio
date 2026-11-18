import { afterEach, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
// Run with node --experimental-strip-types --test lib/server/openrouter.test.ts
// @ts-ignore Node's native test runner needs the .ts extension.
import { generateOpenRouterText, streamAiText } from "./openrouter.ts";

const originalFetch = globalThis.fetch;
const envNames = ["OPENROUTER_API_KEY", "OPENROUTER_MODEL", "OPENROUTER_ZDR", "GROQ_API_KEY", "GROQ_MODEL", "GROQ_FALLBACK_MODELS", "OPENROUTER_FAST_MODEL"];
const originalEnv = envNames.map((name) => process.env[name]);
const options = {
  systemInstruction: "Answer safely",
  prompt: "Test source",
  temperature: 0.2,
  maxOutputTokens: 2048,
};

// Most tests exercise one model; the default chain has its own tests below.
beforeEach(() => {
  process.env.OPENROUTER_FAST_MODEL = "";
});

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
    assert.equal(
      (init?.headers as Record<string, string>).Authorization,
      "Bearer test-key",
    );
    const body = JSON.parse(String(init?.body));
    assert.equal(body.model, "test/model");
    assert.equal(body.max_tokens, 2048);
    assert.deepEqual(body.provider, {
      data_collection: "deny",
      zdr: true,
      require_parameters: true,
    });
    assert.deepEqual(body.response_format, { type: "json_object" });
    assert.match(body.messages[0].content, /Return JSON only/);
    assert.equal(body.messages[1].content, "Test source");
    return Response.json({
      model: "actual/model",
      choices: [{ message: { content: '{"summary":"Ready","entities":[]}' } }],
    });
  };
  const result = await generateOpenRouterText({
    ...options,
    responseJsonSchema: { type: "object" },
  });
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
    return Response.json({
      choices: [{ message: { content: " Answer [SOURCE:1] " } }],
    });
  };
  assert.deepEqual(await generateOpenRouterText(options), {
    text: "Answer [SOURCE:1]",
    model: "openrouter/free",
  });
});

test("explicitly disables optional thinking when complete JSON is required", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  globalThis.fetch = async (_input, init) => {
    assert.deepEqual(JSON.parse(String(init?.body)).reasoning, {
      effort: "none",
      enabled: false,
    });
    return Response.json({
      choices: [
        { message: { content: '{"questions":[]}' }, finish_reason: "stop" },
      ],
    });
  };
  assert.equal(
    (await generateOpenRouterText({ ...options, reasoningEffort: "none" }))
      .text,
    '{"questions":[]}',
  );
});

test("a quiz can select a compatible model without changing other document AI", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  process.env.OPENROUTER_MODEL = "openrouter/free";
  globalThis.fetch = async (_input, init) => {
    assert.equal(JSON.parse(String(init?.body)).model, "test/quiz-model");
    return Response.json({
      model: "test/quiz-model",
      choices: [{ message: { content: "Complete" } }],
    });
  };
  await generateOpenRouterText({ ...options, model: "test/quiz-model" });
  assert.equal(process.env.OPENROUTER_MODEL, "openrouter/free");
});

test("retries transient failures with the same request", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  let calls = 0;
  let firstBody: unknown;
  globalThis.fetch = async (_input, init) => {
    calls++;
    if (calls === 1) firstBody = init?.body;
    assert.equal(init?.body, firstBody);
    return calls < 3
      ? new Response("busy", { status: 503, headers: { "retry-after": "0" } })
      : Response.json({ choices: [{ message: { content: "Recovered" } }] });
  };
  assert.equal((await generateOpenRouterText(options)).text, "Recovered");
  assert.equal(calls, 3);
});

test("does not retry authentication errors or expose submitted content", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  let calls = 0;
  globalThis.fetch = async () => {
    calls++;
    return new Response("private document text", { status: 401 });
  };
  await assert.rejects(generateOpenRouterText(options), {
    message: "OpenRouter request failed (401)",
  });
  assert.equal(calls, 1);
});

test("rejects missing keys before any provider request", async () => {
  process.env.OPENROUTER_API_KEY = " ";
  globalThis.fetch = async () => {
    assert.fail("Must not call provider");
  };
  await assert.rejects(generateOpenRouterText(options), {
    message: "OpenRouter is not configured yet",
  });
});

test("rejects empty, truncated and embedded-error responses", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  for (const payload of [
    { choices: [{ message: { content: "" } }] },
    { choices: [{ message: { content: "Partial" }, finish_reason: "length" }] },
    {
      error: { message: "private document text" },
      choices: [{ message: { content: "Partial" } }],
    },
  ]) {
    globalThis.fetch = async () => Response.json(payload);
    await assert.rejects(generateOpenRouterText(options), {
      message: "OpenRouter returned no complete usable response",
    });
  }
});

test("stops retrying when the request timeout aborts", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  const controller = new AbortController();
  let calls = 0;
  globalThis.fetch = async () => {
    calls++;
    controller.abort(new Error("Timed out"));
    throw controller.signal.reason;
  };
  await assert.rejects(
    generateOpenRouterText({ ...options, signal: controller.signal }),
    { message: "Timed out" },
  );
  assert.equal(calls, 1);
});

test("prefers Groq when a key is configured and ignores OpenRouter-only model ids", async () => {
  process.env.GROQ_API_KEY = "groq-key";
  process.env.OPENROUTER_API_KEY = "test-key";
  delete process.env.GROQ_MODEL;
  globalThis.fetch = async (input, init) => {
    assert.equal(input, "https://api.groq.com/openai/v1/chat/completions");
    assert.equal(
      (init?.headers as Record<string, string>).Authorization,
      "Bearer groq-key",
    );
    const body = JSON.parse(String(init?.body));
    assert.equal(body.model, "llama-3.3-70b-versatile");
    assert.equal(body.provider, undefined);
    assert.equal(body.reasoning, undefined);
    assert.deepEqual(body.response_format, { type: "json_object" });
    return Response.json({
      model: "llama-3.3-70b-versatile",
      choices: [{ message: { content: '{"summary":"Fast"}' } }],
    });
  };
  const result = await generateOpenRouterText({
    ...options,
    model: "cohere/north-mini-code:free",
    reasoningEffort: "none",
    responseJsonSchema: { type: "object" },
  });
  assert.equal(result.model, "llama-3.3-70b-versatile");
  delete process.env.GROQ_API_KEY;
});

test("Groq failures are reported without echoing provider bodies", async () => {
  process.env.GROQ_API_KEY = "groq-key";
  globalThis.fetch = async () =>
    new Response("private document text", { status: 413 });
  await assert.rejects(generateOpenRouterText(options), {
    message: "Groq request failed (413)",
  });
  delete process.env.GROQ_API_KEY;
});

test("a rate-limited Groq model falls through to the next model without waiting", async () => {
  process.env.GROQ_API_KEY = "groq-key";
  delete process.env.OPENROUTER_API_KEY;
  delete process.env.GROQ_MODEL;
  const models: string[] = [];
  globalThis.fetch = async (_input, init) => {
    const model = JSON.parse(String(init?.body)).model as string;
    models.push(model);
    return models.length === 1
      ? new Response("busy", { status: 429, headers: { "retry-after": "30" } })
      : Response.json({ model, choices: [{ message: { content: "Answered" } }] });
  };
  const started = Date.now();
  const result = await generateOpenRouterText(options);
  assert.equal(result.text, "Answered");
  assert.deepEqual(models, ["llama-3.3-70b-versatile", "openai/gpt-oss-120b"]);
  assert.ok(Date.now() - started < 1000);
  delete process.env.GROQ_API_KEY;
});

test("a rejected Groq key moves to OpenRouter instead of failing", async () => {
  process.env.GROQ_API_KEY = "bad-key";
  process.env.OPENROUTER_API_KEY = "test-key";
  const urls: string[] = [];
  globalThis.fetch = async (input) => {
    urls.push(String(input));
    return urls.length === 1
      ? new Response("no", { status: 401 })
      : Response.json({ choices: [{ message: { content: "Answered" } }] });
  };
  assert.equal((await generateOpenRouterText(options)).text, "Answered");
  assert.deepEqual(urls, [
    "https://api.groq.com/openai/v1/chat/completions",
    "https://openrouter.ai/api/v1/chat/completions",
  ]);
  delete process.env.GROQ_API_KEY;
});

const sse = (...chunks: unknown[]) =>
  new Response(chunks.map((chunk) => `data: ${JSON.stringify(chunk)}\n\n`).join("") + "data: [DONE]\n\n");

test("streams words as they arrive and keeps an answer cut off by the length limit", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  globalThis.fetch = async (_input, init) => {
    assert.equal(JSON.parse(String(init?.body)).stream, true);
    return sse(
      { model: "actual/model", choices: [{ delta: { content: "Hello " } }] },
      { choices: [{ delta: { content: "there" } }] },
      { choices: [{ delta: {}, finish_reason: "length" }] },
    );
  };
  const deltas: string[] = [];
  const result = await streamAiText({ ...options, onDelta: (text: string) => deltas.push(text) });
  assert.deepEqual(deltas, ["Hello ", "there"]);
  assert.deepEqual(result, { text: "Hello there", model: "actual/model", truncated: true });
});

test("a stream that fails part-way resets and restarts on the next model", async () => {
  process.env.GROQ_API_KEY = "groq-key";
  delete process.env.OPENROUTER_API_KEY;
  let calls = 0;
  globalThis.fetch = async () =>
    ++calls === 1
      ? sse({ choices: [{ delta: { content: "Partial" } }] }, { error: { message: "overloaded" } })
      : sse({ choices: [{ delta: { content: "Complete" } }] });
  const events: string[] = [];
  const result = await streamAiText({
    ...options,
    onDelta: (text: string) => events.push(text),
    onReset: () => events.push("<reset>"),
  });
  assert.deepEqual(events, ["Partial", "<reset>", "Complete"]);
  assert.equal(result.text, "Complete");
  delete process.env.GROQ_API_KEY;
});

test("OpenRouter tries the fast model first and sends its JSON schema in the prompt only", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  delete process.env.OPENROUTER_MODEL;
  delete process.env.OPENROUTER_FAST_MODEL;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body));
    assert.equal(body.model, "cohere/north-mini-code:free");
    assert.equal(body.response_format, undefined);
    assert.deepEqual(body.provider, { data_collection: "deny" });
    assert.match(body.messages[0].content, /Return JSON only/);
    return Response.json({ choices: [{ message: { content: "{}" } }] });
  };
  await generateOpenRouterText({ ...options, responseJsonSchema: { type: "object" } });
});

test("a model that rejects optional features is asked again without them", async () => {
  process.env.OPENROUTER_API_KEY = "test-key";
  const bodies: Array<Record<string, unknown>> = [];
  globalThis.fetch = async (_input, init) => {
    bodies.push(JSON.parse(String(init?.body)));
    return bodies.length === 1
      ? new Response("unsupported", { status: 400 })
      : Response.json({ choices: [{ message: { content: "{}" } }] });
  };
  await generateOpenRouterText({ ...options, reasoningEffort: "none", responseJsonSchema: { type: "object" } });
  assert.equal(bodies.length, 2);
  assert.ok(bodies[0].reasoning && bodies[0].response_format);
  assert.equal(bodies[1].reasoning, undefined);
  assert.equal(bodies[1].response_format, undefined);
  assert.deepEqual(bodies[1].provider, { data_collection: "deny" });
});
