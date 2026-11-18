type Page = { page: number; text: string };
export type DocumentSummary = { summary: string; entities: Array<{ label: string; value: string }> };

/**
 * Fits a document into the summary prompt. Short pages are sent whole and the
 * remaining allowance is shared between long ones, so every page is
 * represented instead of only the start of the document.
 */
export function summaryInput(pages: Page[], maxChars: number) {
  let remaining = maxChars, longPages = pages.length;
  const share = () => Math.floor(remaining / Math.max(1, longPages));
  const allowance = new Map<number, number>();
  // Smallest pages first, so what they leave unused goes to the longer ones.
  for (const page of [...pages].sort((a, b) => a.text.length - b.text.length)) {
    const take = Math.min(page.text.length, share());
    allowance.set(page.page, take);
    remaining -= take;
    longPages--;
  }
  return pages.map(page => {
    const take = allowance.get(page.page) ?? 0;
    const text = page.text.length > take ? `${page.text.slice(0, take)} …` : page.text;
    return `Page ${page.page}\n${text || "[No readable text on this page]"}`;
  }).join("\n\n");
}

/** Accepts the model's JSON, JSON wrapped in other text, or a plain summary. */
export function parseSummary(raw: string): DocumentSummary {
  const text = raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
  let parsed: { summary?: unknown; entities?: unknown } | null = null;
  for (const candidate of [text, text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1)]) {
    try {
      const value: unknown = JSON.parse(candidate);
      if (value && typeof value === "object") { parsed = value; break; }
    } catch { /* Try the next shape. */ }
  }
  // A model that ignored the JSON instruction but wrote a summary still counts.
  if (!parsed && text && !text.startsWith("{")) return { summary: text.slice(0, 4000), entities: [] };
  if (!parsed || typeof parsed.summary !== "string" || !parsed.summary.trim()) throw new Error("AI returned no usable summary");
  const entities = Array.isArray(parsed.entities) ? parsed.entities.slice(0, 20).flatMap((entity: unknown) => {
    if (!entity || typeof entity !== "object") return [];
    const value = entity as { label?: unknown; value?: unknown };
    return typeof value.label === "string" && typeof value.value === "string"
      ? [{ label: value.label.slice(0, 80), value: value.value.slice(0, 240) }] : [];
  }) : [];
  return { summary: parsed.summary.trim().slice(0, 4000), entities };
}

/**
 * Used only when no model could be reached: the opening of the document in
 * its own words, clearly labelled, so the document is still ready to use.
 */
export function overview(pages: Page[]) {
  const text = pages.map(page => page.text).join(" ").replace(/\s+/g, " ").trim();
  const sentences = (text.slice(0, 900).match(/[^.!?]+[.!?]+|[^.!?]+$/g) || [])
    .map(sentence => sentence.trim()).filter(sentence => sentence.length > 20).slice(0, 5);
  return `### Quick overview\n\nThe AI summary was unavailable, so this shows the opening of the document in its own words.\n\n${sentences.map(sentence => `- ${sentence}`).join("\n")}`;
}
