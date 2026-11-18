const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

export type GenerateOptions = {
  model?: string;
  systemInstruction: string;
  prompt: string;
  temperature: number;
  maxOutputTokens: number;
  responseJsonSchema?: Record<string, unknown>;
  jsonResponse?: boolean;
  reasoningEffort?: "none" | "minimal" | "low" | "medium" | "high";
  signal?: AbortSignal;
  /** Longest one model may take before the next one is tried. */
  attemptTimeoutMs?: number;
};

export type StreamOptions = GenerateOptions & {
  onDelta: (text: string) => void;
  /** Called when a model failed after emitting text and another will restart. */
  onReset?: () => void;
};

export class OpenRouterError extends Error {
  readonly status: number;
  readonly retryAfterMs: number | null;
  constructor(status: number, provider = "OpenRouter", retryAfterMs: number | null = null) {
    super(`${provider} request failed (${status})`);
    this.name = "OpenRouterError";
    this.status = status;
    this.retryAfterMs = retryAfterMs;
  }
}

class IncompleteResponseError extends Error {
  constructor() {
    super("OpenRouter returned no complete usable response");
    this.name = "IncompleteResponseError";
  }
}

export type AiProvider = "groq" | "openrouter";
type Candidate = { provider: AiProvider; apiKey: string; model: string };

/**
 * Groq is preferred when a key is present: its free tier serves models at
 * hundreds of tokens per second. OpenRouter is used after it, or alone.
 */
export const aiProvider = (): AiProvider =>
  process.env.GROQ_API_KEY?.trim() ? "groq" : "openrouter";

export const aiConfigured = () =>
  Boolean(process.env.GROQ_API_KEY?.trim() || process.env.OPENROUTER_API_KEY?.trim());

export const openRouterModel = () =>
  process.env.OPENROUTER_MODEL?.trim() || "openrouter/free";

export const groqModel = () =>
  process.env.GROQ_MODEL?.trim() || "llama-3.3-70b-versatile";

/**
 * Groq rate limits are counted per model, so a second and third model give a
 * busy or rate-limited request somewhere to go immediately instead of waiting.
 */
const groqFallbackModels = () =>
  (process.env.GROQ_FALLBACK_MODELS ?? "openai/gpt-oss-120b,llama-3.1-8b-instant")
    .split(",").map(model => model.trim()).filter(Boolean);

/**
 * Tried before the free router, which picks an arbitrary model per request
 * and is the slowest and least predictable option. Empty disables it.
 */
const openRouterFastModel = () =>
  (process.env.OPENROUTER_FAST_MODEL ?? "cohere/north-mini-code:free").trim();

// These follow a JSON schema given in the prompt but reject response_format.
const PROMPT_ONLY_JSON = new Set(["cohere/north-mini-code:free"]);

const isOpenRouterId = (model: string) =>
  model.endsWith(":free") || model.startsWith("openrouter/");

/**
 * Every model that may serve a request, in order. Per-request models in the
 * codebase are OpenRouter identifiers; Groq ignores those and uses its own.
 */
function candidates(requested: string | undefined): Candidate[] {
  const trimmed = requested?.trim();
  const list: Candidate[] = [];
  const add = (provider: AiProvider, apiKey: string, model: string) => {
    if (model && !list.some(item => item.provider === provider && item.model === model))
      list.push({ provider, apiKey, model });
  };
  const groqKey = process.env.GROQ_API_KEY?.trim();
  if (groqKey) {
    if (trimmed && !isOpenRouterId(trimmed)) add("groq", groqKey, trimmed);
    add("groq", groqKey, groqModel());
    groqFallbackModels().forEach(model => add("groq", groqKey, model));
  }
  const openRouterKey = process.env.OPENROUTER_API_KEY?.trim();
  if (openRouterKey) {
    // With a Groq key, other requested ids are Groq ids and not valid here.
    if (trimmed && (!groqKey || isOpenRouterId(trimmed))) add("openrouter", openRouterKey, trimmed);
    if (openRouterModel() !== "openrouter/free") add("openrouter", openRouterKey, openRouterModel());
    add("openrouter", openRouterKey, openRouterFastModel());
    add("openrouter", openRouterKey, "openrouter/free");
  }
  return list;
}

const RETRYABLE_STATUS = new Set([408, 425, 429, 500, 502, 503, 504]);

function retryAfter(response: Response) {
  const header = response.headers.get("retry-after");
  const seconds = header === null ? NaN : Number(header);
  return Number.isFinite(seconds) && seconds >= 0 ? seconds * 1000 : null;
}

function wait(milliseconds: number, signal: AbortSignal) {
  return new Promise<void>((resolve, reject) => {
    if (signal.aborted) return reject(signal.reason);
    const onAbort = () => {
      clearTimeout(timer);
      reject(signal.reason);
    };
    const timer = setTimeout(() => {
      signal.removeEventListener("abort", onAbort);
      resolve();
    }, milliseconds);
    signal.addEventListener("abort", onAbort, { once: true });
  });
}

function buildRequest(
  options: GenerateOptions,
  { provider, apiKey, model }: Candidate,
  stream: boolean,
  relaxed = false,
): { url: string; headers: Record<string, string>; body: Record<string, unknown> } {
  const messages = [
    {
      role: "system",
      content:
        options.systemInstruction +
        (options.responseJsonSchema
          ? ` Return JSON only, matching this schema: ${JSON.stringify(options.responseJsonSchema)}`
          : ""),
    },
    { role: "user", content: options.prompt },
  ];
  const jsonMode = options.responseJsonSchema && options.jsonResponse !== false && !relaxed && !PROMPT_ONLY_JSON.has(model);
  if (provider === "groq") {
    // Groq is OpenAI-compatible; it has no provider routing block.
    return {
      url: GROQ_URL,
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: {
        model,
        stream,
        temperature: options.temperature,
        max_tokens: options.maxOutputTokens,
        // Reasoning models would otherwise spend the answer budget thinking.
        ...(model.startsWith("openai/gpt-oss") ? { reasoning_effort: "low" } : {}),
        ...(jsonMode ? { response_format: { type: "json_object" } } : {}),
        messages,
      },
    };
  }
  return {
    url: OPENROUTER_URL,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000",
      "X-OpenRouter-Title": "Folio",
    },
    body: {
      model,
      stream,
      temperature: options.temperature,
      max_tokens: options.maxOutputTokens,
      provider: {
        data_collection: "deny",
        ...(process.env.OPENROUTER_ZDR === "true" ? { zdr: true } : {}),
        ...(jsonMode ? { require_parameters: true } : {}),
      },
      ...(options.reasoningEffort && !relaxed
        ? {
            reasoning: {
              effort: options.reasoningEffort,
              ...(options.reasoningEffort === "none" ? { enabled: false } : {}),
            },
          }
        : {}),
      ...(jsonMode ? { response_format: { type: "json_object" } } : {}),
      messages,
    },
  };
}

const providerName = (provider: AiProvider) => (provider === "groq" ? "Groq" : "OpenRouter");

/**
 * Tries each model in turn. A rate limit, outage, slow model or empty reply
 * moves straight to the next model; only when every model was transiently
 * unavailable does the whole list get another pass after a short pause.
 */
async function runChain<T>(
  options: GenerateOptions,
  run: (candidate: Candidate, overall: AbortSignal, timeoutMs: number) => Promise<T>,
  defaultTimeouts: Record<AiProvider, number> = { groq: 20_000, openrouter: 40_000 },
): Promise<T> {
  const list = candidates(options.model);
  if (!list.length) throw new Error("OpenRouter is not configured yet");
  const overall = options.signal || AbortSignal.timeout(45_000);
  const rejectedKeys = new Set<AiProvider>();
  let firstError: unknown;
  for (let pass = 0; pass < 3; pass++) {
    let transient = false;
    let pause = pass === 0 ? 250 : 750;
    for (const candidate of list) {
      if (rejectedKeys.has(candidate.provider)) continue;
      if (overall.aborted) throw overall.reason;
      const timeout = options.attemptTimeoutMs ?? defaultTimeouts[candidate.provider];
      try {
        return await run(candidate, overall, timeout);
      } catch (error) {
        if (overall.aborted) throw error;
        firstError ??= error;
        // Provider errors may echo submitted document text. Log metadata only.
        console.warn("AI model attempt failed", {
          provider: candidate.provider,
          model: candidate.model,
          reason: error instanceof Error ? error.message : "Unknown error",
        });
        if (error instanceof OpenRouterError) {
          if (error.status === 401 || error.status === 403) rejectedKeys.add(candidate.provider);
          else if (RETRYABLE_STATUS.has(error.status)) {
            transient = true;
            if (error.retryAfterMs !== null) pause = Math.min(error.retryAfterMs, 2_000);
          }
        } else if (!(error instanceof IncompleteResponseError)) {
          transient = true; // Network failure or a model that was too slow.
        }
      }
    }
    if (!transient || pass === 2) break;
    await wait(pause, overall);
  }
  throw firstError ?? new Error("OpenRouter did not return a response");
}

async function send(options: GenerateOptions, candidate: Candidate, stream: boolean, signal: AbortSignal) {
  const post = (relaxed: boolean) => {
    const request = buildRequest(options, candidate, stream, relaxed);
    return fetch(request.url, { method: "POST", headers: request.headers, body: JSON.stringify(request.body), signal });
  };
  let response = await post(false);
  // OpenRouter rejects a request when the chosen model lacks an optional
  // feature. The schema is also in the prompt, so ask again without extras.
  if ((response.status === 400 || response.status === 404) && candidate.provider === "openrouter"
    && (options.reasoningEffort || options.responseJsonSchema)) {
    await response.body?.cancel().catch(() => undefined);
    response = await post(true);
  }
  if (!response.ok) {
    await response.body?.cancel().catch(() => undefined);
    // Never expose the error body: it may echo submitted document text.
    throw new OpenRouterError(response.status, providerName(candidate.provider), retryAfter(response));
  }
  return response;
}

export async function generateOpenRouterText(options: GenerateOptions) {
  return runChain(options, async (candidate, overall, timeoutMs) => {
    const response = await send(options, candidate, false, AbortSignal.any([overall, AbortSignal.timeout(timeoutMs)]));
    const json = (await response.json()) as {
      model?: string;
      error?: unknown;
      choices?: Array<{ message?: { content?: string }; finish_reason?: string }>;
      usage?: {
        completion_tokens?: number;
        completion_tokens_details?: { reasoning_tokens?: number };
      };
    };
    const choice = json.choices?.[0];
    const text =
      typeof choice?.message?.content === "string"
        ? choice.message.content.trim()
        : "";
    if (json.error || !text || choice?.finish_reason === "length") {
      console.warn("Incomplete AI completion", {
        provider: candidate.provider,
        model: json.model,
        finishReason: choice?.finish_reason,
        completionTokens: json.usage?.completion_tokens,
        reasoningTokens: json.usage?.completion_tokens_details?.reasoning_tokens,
      });
      throw new IncompleteResponseError();
    }
    return { text, model: json.model || candidate.model };
  });
}

/**
 * Streams an answer as it is written. A model that stalls or fails is replaced
 * by the next one; an answer cut off by the length limit is kept as written.
 */
export async function streamAiText(options: StreamOptions) {
  return runChain(options, async (candidate, overall, timeoutMs) => {
    // The attempt timeout bounds the wait for the first words; once text is
    // flowing, only a 15 second stall between chunks ends the attempt.
    const attempt = new AbortController();
    let timer = setTimeout(() => attempt.abort(new Error("AI model was too slow")), timeoutMs);
    let pending = "", text = "", model = candidate.model, truncated = false;
    const handle = (line: string) => {
      if (!line.startsWith("data:")) return;
      const data = line.slice(5).trim();
      if (!data || data === "[DONE]") return;
      let chunk: { model?: string; error?: unknown; choices?: Array<{ delta?: { content?: unknown }; finish_reason?: string | null }> };
      try { chunk = JSON.parse(data); } catch { return; }
      if (chunk.error) throw new IncompleteResponseError();
      if (chunk.model) model = chunk.model;
      const choice = chunk.choices?.[0];
      if (typeof choice?.delta?.content === "string" && choice.delta.content) {
        text += choice.delta.content;
        options.onDelta(choice.delta.content);
      }
      if (choice?.finish_reason === "length") truncated = true;
    };
    try {
      const response = await send(options, candidate, true, AbortSignal.any([overall, attempt.signal]));
      if (!response.body) throw new IncompleteResponseError();
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      for (;;) {
        const { done, value } = await reader.read();
        pending += decoder.decode(value || new Uint8Array(), { stream: !done });
        const lines = pending.split("\n");
        pending = lines.pop() || "";
        lines.forEach(handle);
        if (text) {
          clearTimeout(timer);
          timer = setTimeout(() => attempt.abort(new Error("AI stream stalled")), 15_000);
        }
        if (done) { handle(pending); break; }
      }
      if (!text.trim()) throw new IncompleteResponseError();
      return { text: text.trim(), model, truncated };
    } catch (error) {
      if (text && !overall.aborted) options.onReset?.();
      throw error;
    } finally {
      clearTimeout(timer);
      attempt.abort();
    }
  }, { groq: 6_000, openrouter: 20_000 });
}
