// @ts-ignore Node's native test runner uses explicit TypeScript extensions.
import { sourcePages, type VaultDocument } from "./models.ts";
export type DeadlineCandidate = {
  documentId: string;
  title: string;
  action: string;
  dateText: string;
  excerpt: string;
  key: string;
  due: string | null;
  page: number | null;
};
const cue =
  /\b(deadline|due|closing\s+date|closes?|submit(?:ted)?\s+by|submission|pay(?:ment)?\s+by|last\s+(?:day|date)|no\s+later\s+than)\b/i;
const uncertain =
  /\b(example|sample|tentative|provisional|estimated|approximately|not\s+(?:due|a\s+deadline))\b/i;
const monthPattern =
  "January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec";
const tokens = () =>
  new RegExp(
    `\\b(?:\\d{4}[-/]\\d{1,2}[-/]\\d{1,2}|\\d{1,2}[-/.]\\d{1,2}[-/.]\\d{4}|\\d{1,2}(?:st|nd|rd|th)?\\s+(?:${monthPattern})(?:\\s*,?\\s*\\d{4})?|(?:${monthPattern})\\s+\\d{1,2}(?:st|nd|rd|th)?(?:\\s*,?\\s*\\d{4})?)\\b`,
    "gi",
  );
export function parseDeadlineDate(value: string): string | null {
  const text = value
    .trim()
    .toLowerCase()
    .replace(/(\d)(st|nd|rd|th)\b/g, "$1");
  let year = 0,
    month = 0,
    day = 0;
  let match = text.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/);
  if (match) {
    year = +match[1];
    month = +match[2];
    day = +match[3];
  } else {
    match = text.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$/);
    if (match) {
      const first = +match[1],
        second = +match[2];
      if ((first > 12 && second <= 12) || first === second) {
        day = first;
        month = second;
      } else if (second > 12 && first <= 12) {
        month = first;
        day = second;
      } else return null;
      year = +match[3];
    } else {
      match = text.match(/^(\d{1,2})\s+([a-z]+)\s*,?\s*(\d{4})$/);
      const reversed = text.match(/^([a-z]+)\s+(\d{1,2})\s*,?\s*(\d{4})$/);
      if (!match && !reversed) return null;
      const named = match ? match[2] : reversed![1];
      month =
        [
          "jan",
          "feb",
          "mar",
          "apr",
          "may",
          "jun",
          "jul",
          "aug",
          "sep",
          "oct",
          "nov",
          "dec",
        ].indexOf(named.slice(0, 3)) + 1;
      day = +(match ? match[1] : reversed![2]);
      year = +(match ? match[3] : reversed![3]);
    }
  }
  const date = new Date(year, month - 1, day);
  if (
    year < 1900 ||
    year > 2200 ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    date.getFullYear() !== year ||
    date.getMonth() !== month - 1 ||
    date.getDate() !== day
  )
    return null;
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}
function kind(text: string) {
  return /\b(submit|submission|assignment|assessment)\b/i.test(text)
    ? "Submission"
    : /\b(pay|payment|fees?|instalment|installment)\b/i.test(text)
      ? "Payment"
      : /\b(application|apply|applications)\b/i.test(text)
        ? "Application"
        : /\b(register|registration|enrolment|enrollment)\b/i.test(text)
          ? "Registration"
          : "Document";
}
export function extractDeadlines(
  documents: VaultDocument[],
): DeadlineCandidate[] {
  return documents.flatMap((doc) => {
    const candidates = new Map<string, DeadlineCandidate>();
    const sections = sourcePages(doc);
    const sourceDates = new Set(
      sections.flatMap((p) =>
        [...p.text.matchAll(tokens())].map((m) => parseDeadlineDate(m[0])),
      ),
    );
    const add = (
      context: string,
      page: number | null,
      entityLabel?: string,
    ) => {
      if (!cue.test(context)) return;
      const dates = [...context.matchAll(tokens())];
      dates.forEach((token, i) => {
        if (
          !entityLabel &&
          dates.length > 1 &&
          !cue.test(
            context.slice(
              i ? dates[i - 1].index! + dates[i - 1][0].length : 0,
              token.index,
            ),
          )
        )
          return;
        const parsed = parseDeadlineDate(token[0]);
        const due =
          uncertain.test(context) ||
          (!!entityLabel && (dates.length > 1 || !sourceDates.has(parsed)))
            ? null
            : parsed;
        const category = kind(context),
          key = `${doc.id}|${category}|${due || token[0].toLowerCase()}`;
        if (
          due &&
          category === "Document" &&
          [...candidates.values()].some(
            (c) => c.due === due && !c.key.includes("|Document|"),
          )
        )
          return;
        if (due && category !== "Document")
          for (const [existingKey, existing] of candidates)
            if (existing.due === due && existing.key.includes("|Document|"))
              candidates.delete(existingKey);
        if (!candidates.has(key))
          candidates.set(key, {
            documentId: doc.id,
            title: doc.title,
            action: entityLabel || `${category} deadline`,
            dateText: token[0],
            due,
            page,
            key,
            excerpt: context
              .slice(
                Math.max(0, token.index! - 160),
                token.index! + token[0].length + 160,
              )
              .trim(),
          });
      });
    };
    sections.forEach((section) => {
      const lines = section.text.split(/[\n\r]+/);
      lines.forEach((line, index) => {
        if (!cue.test(line)) return;
        const context = tokens().test(line)
          ? line
          : `${line} ${lines[index + 1] || ""}`;
        context
          .split(/(?<=[.!?;])\s+(?=[A-Z])/)
          .forEach((sentence) => add(sentence, section.page));
      });
    });
    doc.entities.forEach((entity) => {
      if (cue.test(entity.label))
        add(`${entity.label}: ${entity.value}`, null, entity.label);
    });
    return [...candidates.values()];
  });
}
