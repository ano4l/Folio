const MARKER = /[\[（(【]\s*SOURCE\s*[:#-]?\s*(\d+)\s*[\]）)】]/gi;

/**
 * Normalises citation markers to [SOURCE:n] and removes any that point at a
 * source that was never supplied, so an answer is delivered either way and
 * only real evidence is ever linked.
 */
export function cleanSourceMarkers(answer: string, sourceCount: number) {
  const numbers: number[] = [];
  const text = answer.replace(MARKER, (_marker, digits: string) => {
    const number = Number(digits);
    if (number < 1 || number > sourceCount) return "";
    if (!numbers.includes(number)) numbers.push(number);
    return `[SOURCE:${number}]`;
  }).replace(/[ \t]+([.,;:!?])/g, "$1").replace(/[ \t]{2,}/g, " ").trim();
  return { text, numbers };
}

/**
 * The answer of last resort when no model can be reached: the passages that
 * best match the request, quoted directly and cited, with nothing generated.
 */
export function passageAnswer(passages: Array<{ title: string; page: number | null; text: string }>) {
  const shown = passages.slice(0, 3);
  const quotes = shown.map((passage, index) => {
    const excerpt = passage.text.replace(/\s+/g, " ").trim();
    const short = excerpt.length > 420 ? `${excerpt.slice(0, 420).replace(/\s+\S*$/, "")} …` : excerpt;
    return `**${passage.title}${passage.page ? `, page ${passage.page}` : ""}** [SOURCE:${index + 1}]\n\n> ${short}`;
  });
  return {
    text: `I could not reach the AI model just now, so here are the passages from your documents that best match your question:\n\n${quotes.join("\n\n")}\n\nAsk again in a moment for a full written answer.`,
    numbers: shown.map((_, index) => index + 1),
  };
}

/**
 * Trims a long page to the window that best matches the request, so prompts
 * stay small enough to be fast and to fit free-tier per-minute token limits.
 */
export function focusExcerpt(content: string, query: string, maxChars: number) {
  if (content.length <= maxChars) return content;
  const words = [...new Set(query.toLowerCase().split(/[^a-z0-9]+/).filter(word => word.length > 2))], lower = content.toLowerCase(), step = Math.max(1, Math.floor(maxChars / 2));
  let best = 0, bestScore = -1;
  for (let start = 0; start < content.length; start += step) {
    const window = lower.slice(start, start + maxChars);
    const windowScore = words.reduce((total, word) => total + (window.includes(word) ? 1 : 0), 0);
    if (windowScore > bestScore) { best = start; bestScore = windowScore; }
    if (start + maxChars >= content.length) break;
  }
  return `${best ? "… " : ""}${content.slice(best, best + maxChars).trim()}${best + maxChars < content.length ? " …" : ""}`;
}
