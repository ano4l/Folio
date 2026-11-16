import { PDFDocument, rgb } from "pdf-lib";
import fontkit from "@pdf-lib/fontkit";
import type { Activity, Card, Note, Task } from "./models";
export function filename(title: string) {
  return title.replace(/[^\p{L}\p{N} _.-]/gu, "_").slice(0, 100) || "Folio";
}
export function download(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob),
    link = document.createElement("a");
  link.href = url;
  link.download = filename(name);
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
export async function textPdf(
  title: string,
  text: string,
): Promise<Uint8Array<ArrayBuffer>> {
  const pdf = await PDFDocument.create();
  pdf.registerFontkit(fontkit);
  const response = await fetch("/fonts/dm-sans-latin-400-normal.woff");
  if (!response.ok)
    throw new Error("The export font could not be loaded. Try again.");
  const font = await pdf.embedFont(await response.arrayBuffer(), {
    subset: true,
  });
  let page = pdf.addPage([595.28, 841.89]),
    y = 788;
  const write = (line: string, size = 11) => {
    if (y < 52) {
      page = pdf.addPage([595.28, 841.89]);
      y = 788;
    }
    page.drawText(line, {
      x: 48,
      y,
      font,
      size,
      color: rgb(0.043, 0.075, 0.169),
    });
    y -= size * 1.65;
  };
  const wrap = (value: string, size: number) => {
    for (const line of value.replace(/\t/g, "    ").split(/\r?\n/)) {
      if (!line) {
        write(" ", size);
        continue;
      }
      let current = "";
      for (const char of line) {
        if (font.widthOfTextAtSize(current + char, size) > 495) {
          write(current, size);
          current = "";
        }
        current += char;
      }
      if (current) write(current, size);
    }
  };
  wrap(title, 18);
  y -= 10;
  wrap(text, 11);
  pdf.setTitle(title);
  pdf.setCreator("Folio");
  return (await pdf.save()) as Uint8Array<ArrayBuffer>;
}
export const pdfBlob = (bytes: Uint8Array<ArrayBuffer>) =>
  new Blob([bytes], { type: "application/pdf" });
export function studyMarkdown(title: string, notes: Note[], cards: Card[]) {
  return (
    `# ${title}\n\n` +
    notes
      .map(
        (n) =>
          `## ${n.title}\n\n${n.text}\n\nSource: ${n.documentTitle}${n.sourcePage ? `, page ${n.sourcePage}` : " (page unavailable)"}\n`,
      )
      .join("\n") +
    (cards.length
      ? "\n## Revision cards\n\n" +
        cards
          .map(
            (c) =>
              `### ${c.front}\n\n${c.back}\n\nSource: ${c.documentTitle}${c.sourcePage ? `, page ${c.sourcePage}` : " (page unavailable)"}\n${c.sourceExcerpt ? `\n> ${c.sourceExcerpt}\n` : ""}`,
          )
          .join("\n")
      : "")
  );
}
const icsEscape = (text: string) =>
  text
    .replace(/\\/g, "\\\\")
    .replace(/\r?\n/g, "\\n")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,");
export function calendarExport(tasks: Task[]) {
  const stamp =
    new Date().toISOString().replace(/[-:]/g, "").split(".")[0] + "Z";
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Folio//Tasks//EN",
    "CALSCALE:GREGORIAN",
  ];
  for (const task of tasks)
    lines.push(
      "BEGIN:VEVENT",
      `UID:${task.id}@folio`,
      `DTSTAMP:${stamp}`,
      `DTSTART;VALUE=DATE:${task.due.replace(/-/g, "")}`,
      `SUMMARY:${icsEscape(task.title)}`,
      `DESCRIPTION:${icsEscape(task.excerpt || "Folio task")}`,
      `STATUS:${task.completed ? "CONFIRMED" : "TENTATIVE"}`,
      "END:VEVENT",
    );
  lines.push("END:VCALENDAR");
  // Fold by UTF-8 bytes, as required by RFC 5545.
  return lines
    .flatMap((line) => {
      const folded = [];
      let segment = "",
        size = 0;
      for (const character of line) {
        const length = new TextEncoder().encode(character).length;
        if (size + length > 73) {
          folded.push(segment);
          segment = " ";
          size = 1;
        }
        segment += character;
        size += length;
      }
      folded.push(segment);
      return folded;
    })
    .join("\r\n");
}
export function activityCsv(items: Activity[]) {
  const cell = (value: string) =>
    `"${(/^[\s]*[=+\-@\t\r]/.test(value) ? "'" : "") + value.replace(/"/g, '""')}"`;
  return [
    ["Time", "Category", "Action", "Detail"],
    ...items.map((item) => [item.at, item.category, item.action, item.detail]),
  ]
    .map((row) => row.map(cell).join(","))
    .join("\r\n");
}
