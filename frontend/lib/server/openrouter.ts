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
};

export class OpenRouterError extends Error {
  readonly status: number;
  constructor(status: number, provider = "OpenRouter") {
    super(`${provider} request failed (${status})`);
    this.name = "OpenRouterError";
    this.status = status;
  }
}

export type AiProvider = "groq" | "openrouter";

/**
 * Groq is preferred when a key is present: its free tier serves Llama models
 * at hundreds of tokens per second with no daily request cap small enough to
 * matter for a demo. OpenRouter's free router remains the fallback.
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
 * Per-request models in the codebase are OpenRouter identifiers. When Groq is
 * active they are ignored unless they are plain Groq model ids, so every
 * feature uses the one configured fast model.
 */
function resolveModel(requested: string | undefined, provider: AiProvider) {
  const trimmed = requested?.trim();
  if (provider === "openrouter") return trimmed || openRouterModel();
  if (trimmed && !trimmed.endsWith(":free") && !trimmed.startsWith("openrouter/")) return trimmed;
  return groqModel();
}

const RETRYABLE_STATUS = new Set([408, 425, 429, 500, 502, 503, 504]);

function retryDelay(response: Response, attempt: number) {
  const header = response.headers.get("retry-after");
  const retryAfter = header === null ? NaN : Number(header);
  return Number.isFinite(retryAfter) && retryAfter >= 0
    ? Math.min(retryAfter * 1000, 2_000)
    : attempt === 0
      ? 250
      : 750;
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
  provider: AiProvider,
  apiKey: string,
  model: string,
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
  const jsonMode = options.responseJsonSchema && options.jsonResponse !== false;
  if (provider === "groq") {
    // Groq is OpenAI-compatible; it has no provider routing or reasoning block.
    return {
      url: GROQ_URL,
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: {
        model,
        stream: false,
        temperature: options.temperature,
        max_tokens: options.maxOutputTokens,
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
      stream: false,
      temperature: options.temperature,
      max_tokens: options.maxOutputTokens,
      provider: {
        data_collection: "deny",
        ...(process.env.OPENROUTER_ZDR === "true" ? { zdr: true } : {}),
        ...(options.responseJsonSchema ? { require_parameters: true } : {}),
      },
      ...(options.reasoningEffort
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

export async function generateOpenRouterText(options: GenerateOptions) {
  const provider = aiProvider();
  const apiKey = (provider === "groq" ? process.env.GROQ_API_KEY : process.env.OPENROUTER_API_KEY)?.trim();
  if (!apiKey) throw new Error("OpenRouter is not configured yet");
  const model = resolveModel(options.model, provider);
  const signal = options.signal || AbortSignal.timeout(45_000);
  const request = buildRequest(options, provider, apiKey, model);
  const init: RequestInit = {
    method: "POST",
    headers: request.headers,
    body: JSON.stringify(request.body),
    signal,
  };
  let response: Response | undefined;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      response = await fetch(request.url, init);
    } catch (error) {
      if (signal.aborted || attempt === 2) throw error;
      await wait(attempt === 0 ? 250 : 750, signal);
      continue;
    }
    if (response.ok || !RETRYABLE_STATUS.has(response.status) || attempt === 2)
      break;
    await response.body?.cancel().catch(() => undefined);
    await wait(retryDelay(response, attempt), signal);
  }
  if (!response) throw new Error("OpenRouter did not return a response");
  // Provider errors may echo submitted document text. Never expose their body.
  if (!response.ok) throw new OpenRouterError(response.status, provider === "groq" ? "Groq" : "OpenRouter");
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
      provider,
      model: json.model,
      finishReason: choice?.finish_reason,
      completionTokens: json.usage?.completion_tokens,
      reasoningTokens: json.usage?.completion_tokens_details?.reasoning_tokens,
    });
    throw new Error("OpenRouter returned no complete usable response");
  }
  return { text, model: json.model || model };
}
