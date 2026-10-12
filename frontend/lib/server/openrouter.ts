const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

type GenerateOptions = {
  systemInstruction: string;
  prompt: string;
  temperature: number;
  maxOutputTokens: number;
  responseJsonSchema?: Record<string, unknown>;
  signal?: AbortSignal;
};

export const openRouterModel = () => process.env.OPENROUTER_MODEL?.trim() || "openrouter/free";

const RETRYABLE_STATUS = new Set([408, 425, 429, 500, 502, 503, 504]);

function retryDelay(response: Response, attempt: number) {
  const header = response.headers.get("retry-after");
  const retryAfter = header === null ? NaN : Number(header);
  return Number.isFinite(retryAfter) && retryAfter >= 0
    ? Math.min(retryAfter * 1000, 2_000)
    : attempt === 0 ? 250 : 750;
}

function wait(milliseconds: number, signal: AbortSignal) {
  return new Promise<void>((resolve, reject) => {
    if (signal.aborted) return reject(signal.reason);
    const onAbort = () => { clearTimeout(timer); reject(signal.reason); };
    const timer = setTimeout(() => { signal.removeEventListener("abort", onAbort); resolve(); }, milliseconds);
    signal.addEventListener("abort", onAbort, { once: true });
  });
}

export async function generateOpenRouterText(options: GenerateOptions) {
  const apiKey = process.env.OPENROUTER_API_KEY?.trim();
  if (!apiKey) throw new Error("OpenRouter is not configured yet");
  const model = openRouterModel();
  const signal = options.signal || AbortSignal.timeout(45_000);
  const init: RequestInit = {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000",
      "X-OpenRouter-Title": "Folio",
    },
    body: JSON.stringify({
      model,
      stream: false,
      temperature: options.temperature,
      max_tokens: options.maxOutputTokens,
      provider: {
        data_collection: "deny",
        ...(process.env.OPENROUTER_ZDR === "true" ? { zdr: true } : {}),
        ...(options.responseJsonSchema ? { require_parameters: true } : {}),
      },
      ...(options.responseJsonSchema ? { response_format: { type: "json_object" } } : {}),
      messages: [
        { role: "system", content: options.systemInstruction + (options.responseJsonSchema
          ? ` Return JSON only, matching this schema: ${JSON.stringify(options.responseJsonSchema)}` : "") },
        { role: "user", content: options.prompt },
      ],
    }),
    signal,
  };
  let response: Response | undefined;
  for (let attempt = 0; attempt < 3; attempt++) {
    try { response = await fetch(OPENROUTER_URL, init); }
    catch (error) {
      if (signal.aborted || attempt === 2) throw error;
      await wait(attempt === 0 ? 250 : 750, signal);
      continue;
    }
    if (response.ok || !RETRYABLE_STATUS.has(response.status) || attempt === 2) break;
    await response.body?.cancel().catch(() => undefined);
    await wait(retryDelay(response, attempt), signal);
  }
  if (!response) throw new Error("OpenRouter did not return a response");
  // Provider errors may echo submitted document text. Never expose their body.
  if (!response.ok) throw new Error(`OpenRouter request failed (${response.status})`);
  const json = await response.json() as {
    model?: string;
    error?: unknown;
    choices?: Array<{ message?: { content?: string }; finish_reason?: string }>;
  };
  const choice = json.choices?.[0];
  const text = typeof choice?.message?.content === "string" ? choice.message.content.trim() : "";
  if (json.error || !text || choice?.finish_reason === "length") throw new Error("OpenRouter returned no complete usable response");
  return { text, model: json.model || model };
}
