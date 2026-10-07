export type DocumentPage = { page: number; text: string };
const PREFIX = "FOLIO_PAGES_V1\n";
export const MAX_EXTRACTED_TEXT = 120_000;

export function validatePages(value: unknown): DocumentPage[] {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > 20) throw new Error("Invalid extracted pages");
  let length = 0;
  return value.map((item, index) => {
    if (!item || item.page !== index + 1 || typeof item.text !== "string") throw new Error("Invalid extracted page order");
    length += item.text.length;
    if (length > MAX_EXTRACTED_TEXT) throw new Error("Extracted text exceeds the supported limit");
    return { page: item.page, text: item.text.replaceAll("\u0000", "").trim() };
  });
}

export function encodePages(pages: DocumentPage[]): string {
  if (pages.reduce((total, page) => total + page.text.length, 0) > MAX_EXTRACTED_TEXT) {
    throw new Error("This document is too long to read completely. Split it into smaller documents.");
  }
  return PREFIX + JSON.stringify(pages);
}

export function decodePages(content: string): DocumentPage[] | null {
  if (!content.startsWith(PREFIX)) return null;
  try {
    const pages: unknown = JSON.parse(content.slice(PREFIX.length));
    if (!Array.isArray(pages) || !pages.every(p => p && Number.isInteger(p.page) && p.page > 0 && typeof p.text === "string")) return null;
    return pages;
  } catch { return null; }
}

export function readableText(content: string): string {
  const pages = decodePages(content);
  return pages ? pages.map(p => `Page ${p.page}\n${p.text || "[No readable text on this page]"}`).join("\n\n") : content;
}
