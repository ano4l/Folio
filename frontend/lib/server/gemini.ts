const GEMINI_API_ROOT = "https://generativelanguage.googleapis.com/v1beta/models";

type GeminiPart = { text?: string };
type GeminiResponse = {
  candidates?: Array<{ content?: { parts?: GeminiPart[] }; finishReason?: string }>;
  modelVersion?: string;
};

type GenerateOptions = {
  systemInstruction: string;
  prompt: string;
  temperature: number;
  maxOutputTokens: number;
  responseJsonSchema?: Record<string, unknown>;
  signal?: AbortSignal;
};

export const geminiModel = () => process.env.GEMINI_MODEL?.trim() || "gemini-3.8-flash";

const RETRYABLE_STATUS = new Set([408, 425, 429, 500, 502, 503, 504]);

function retryDelay(response: Response, attempt: number) {
  const retryAfter = Number(response.headers.get("retry-after"));
  if (Number.isFinite(retryAfter) && retryAfter >= 0) {
    return Math.min(retryAfter * 1000, 2_000);
  }
  return attempt === 0 ? 250 : 750;
}

function wait(milliseconds: number, signal?: AbortSignal) {
  return new Promise<void>((resolve, reject) => {
    if (signal?.aborted) return reject(signal.reason);
    const timer = setTimeout(resolve, milliseconds);
    signal?.addEventListener("abort", () => {
      clearTimeout(timer);
      reject(signal.reason);
    }, { once: true });
  });
}

export async function generateGeminiText(options: GenerateOptions) {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey) throw new Error("Gemini is not configured yet");

  const model = geminiModel();
  const generationConfig = {
    maxOutputTokens: options.maxOutputTokens,
    // Gemini 3 models reason before answering. Low prevents short document
    // summaries from spending their complete output allowance on thinking.
    thinkingConfig: { thinkingLevel: "low" },
    ...(!model.startsWith("gemini-3") ? { temperature: options.temperature } : {}),
    ...(options.responseJsonSchema ? {
      responseMimeType: "application/json",
      responseJsonSchema: options.responseJsonSchema,
    } : {}),
  };
  const signal = options.signal || AbortSignal.timeout(45_000);
  const url = `${GEMINI_API_ROOT}/${encodeURIComponent(model)}:generateContent`;
  const init: RequestInit = {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: options.systemInstruction }] },
      contents: [{ role: "user", parts: [{ text: options.prompt }] }],
      generationConfig,
    }),
    signal,
  };

  let response: Response | undefined;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      response = await fetch(url, init);
    } catch (error) {
      if (signal.aborted || attempt === 2) throw error;
      await wait(attempt === 0 ? 250 : 750, signal);
      continue;
    }
    if (response.ok || !RETRYABLE_STATUS.has(response.status) || attempt === 2) break;
    await response.body?.cancel().catch(() => undefined);
    await wait(retryDelay(response, attempt), signal);
  }

  if (!response) throw new Error("Gemini did not return a response");

  if (!response.ok) {
    // Do not log the response body: provider errors can echo submitted content.
    console.error(`Gemini request failed with HTTP ${response.status}`);
    throw new Error(`Gemini request failed (${response.status})`);
  }

  const json = await response.json() as GeminiResponse;
  const text = json.candidates?.[0]?.content?.parts?.map(part => part.text || "").join("").trim() || "";
  if (!text) {
    const finishReason = json.candidates?.[0]?.finishReason;
    throw new Error(`Gemini returned no usable response${finishReason ? ` (${finishReason})` : ""}`);
  }
  return { text, model: json.modelVersion || model };
}
