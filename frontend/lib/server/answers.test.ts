import { test } from "node:test";
import assert from "node:assert/strict";
// @ts-ignore Node's native test runner needs the .ts extension.
import { cleanSourceMarkers, focusExcerpt, passageAnswer } from "./answers.ts";
// @ts-ignore Node's native test runner needs the .ts extension.
import { overview, parseSummary, summaryInput } from "./summary.ts";

test("citation markers are normalised and unsupported ones removed, never the answer", () => {
  assert.deepEqual(cleanSourceMarkers("Due Friday (source 2). Fee is R50 [SOURCE:9]. Also [Source #1].", 2), {
    text: "Due Friday [SOURCE:2]. Fee is R50. Also [SOURCE:1].",
    numbers: [2, 1],
  });
  assert.deepEqual(cleanSourceMarkers("A plain answer.", 3), { text: "A plain answer.", numbers: [] });
});

test("the last-resort answer quotes and cites the best passages", () => {
  const answer = passageAnswer([
    { title: "Lease", page: 2, text: "Rent is due   on the first." },
    { title: "Notes", page: null, text: "x".repeat(900) },
  ]);
  assert.match(answer.text, /\*\*Lease, page 2\*\* \[SOURCE:1\]\n\n> Rent is due on the first\./);
  assert.match(answer.text, /\*\*Notes\*\* \[SOURCE:2\]/);
  assert.deepEqual(answer.numbers, [1, 2]);
  assert.ok(answer.text.length < 1200);
});

test("summary input represents every page within the allowance", () => {
  const input = summaryInput([
    { page: 1, text: "a".repeat(5000) },
    { page: 2, text: "short page" },
    { page: 3, text: "c".repeat(5000) },
  ], 1010);
  assert.match(input, /Page 1\na{500} …/);
  assert.match(input, /Page 2\nshort page\n/);
  assert.match(input, /Page 3\nc{500} …/);
});

test("summaries are accepted as JSON, wrapped JSON or plain text", () => {
  assert.deepEqual(parseSummary('```json\n{"summary":"Ready","entities":[{"label":"Due","value":"Friday"},{"label":1}]}\n```'),
    { summary: "Ready", entities: [{ label: "Due", value: "Friday" }] });
  assert.equal(parseSummary('Here you go: {"summary":"Wrapped","entities":[]} Thanks').summary, "Wrapped");
  assert.deepEqual(parseSummary("## Overview\n- A point"), { summary: "## Overview\n- A point", entities: [] });
  assert.throws(() => parseSummary('{"summary":""}'));
});

test("the offline overview is labelled and built from the document text", () => {
  const text = overview([{ page: 1, text: "This lease begins on 1 March 2026. Rent is R4,500 per month. Ok." }]);
  assert.match(text, /AI summary was unavailable/);
  assert.match(text, /- This lease begins on 1 March 2026\.\n- Rent is R4,500 per month\./);
});

test("long evidence is trimmed to the window matching the request", () => {
  const content = `${"filler ".repeat(400)}The deposit is refundable within 14 days. ${"filler ".repeat(400)}`;
  const excerpt = focusExcerpt(content, "when is the deposit refundable", 600);
  assert.ok(excerpt.includes("deposit is refundable"));
  assert.ok(excerpt.length < 620);
  assert.equal(focusExcerpt("short", "anything", 600), "short");
});
