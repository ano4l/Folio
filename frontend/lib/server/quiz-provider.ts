// @ts-ignore Node's native test runner uses explicit TypeScript extensions.
import { OpenRouterError, type GenerateOptions } from "./openrouter.ts";

type Generate = (
  options: GenerateOptions,
) => Promise<{ text: string; model: string }>;
const unavailable = new Set([404, 408, 425, 429, 500, 502, 503, 504]);

export function quizGenerator(
  generate: Generate,
  primary: string,
  fallback: string,
) {
  let selected = primary;
  return async (options: GenerateOptions) => {
    const run = (model: string) =>
      generate({
        ...options,
        model,
        // This endpoint follows the supplied JSON schema through the prompt.
        // Questions still pass the same structural and source-quote validation.
        jsonResponse: model !== "cohere/north-mini-code:free",
      });
    try {
      return await run(selected);
    } catch (error) {
      if (
        !(error instanceof OpenRouterError) ||
        !unavailable.has(error.status) ||
        selected !== primary ||
        !fallback ||
        fallback === primary ||
        options.signal?.aborted
      )
        throw error;
      selected = fallback;
      return run(selected);
    }
  };
}
