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

export async function generateGeminiText(options: GenerateOptions) {
  const apiKey = process.env.GEMINI_API_KEY?.trim();
  if (!apiKey) throw new Error("Gemini is not configured yet");

  const model = geminiModel();
  const generationConfig = {
    temperature: options.temperature,
    maxOutputTokens: options.maxOutputTokens,
    ...(options.responseJsonSchema ? {
      responseMimeType: "application/json",
      responseJsonSchema: options.responseJsonSchema,
    } : {}),
  };
  const response = await fetch(`${GEMINI_API_ROOT}/${encodeURIComponent(model)}:generateContent`, {
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
    signal: options.signal || AbortSignal.timeout(45_000),
  });

  if (!response.ok) {
    // Do not log the response body: provider errors can echo submitted content.
    console.error(`Gemini request failed with HTTP ${response.status}`);
    throw new Error(`Gemini request failed (${response.status})`);
  }

  const json = await response.json() as GeminiResponse;
  const text = json.candidates?.[0]?.content?.parts?.map(part => part.text || "").join("").trim() || "";
  if (!text) throw new Error("Gemini returned no usable response");
  return { text, model: json.modelVersion || model };
}
