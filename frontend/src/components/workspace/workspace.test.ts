import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { PDFDocument } from "pdf-lib";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
// @ts-ignore Node's native test runner uses explicit TypeScript extensions.
import { AnswerMarkdown, citationByNumber } from "./AnswerMarkdown.ts";
// @ts-ignore Node's native test runner uses explicit TypeScript extensions.
import { parseDeadlineDate, extractDeadlines } from "./deadlines.ts";
// @ts-ignore Node's native test runner uses explicit TypeScript extensions.
import {
  answerQuestion,
  emptyWorkspace,
  sourcePages,
  reviewCard,
  dueCards,
  quizProgress,
  type VaultDocument,
  type Quiz,
} from "./models.ts";
// @ts-ignore Node's native test runner uses explicit TypeScript extensions.
import { encryptWorkspace, decryptWorkspace } from "./storage.ts";
// @ts-ignore Node's native test runner uses explicit TypeScript extensions.
import {
  activityCsv,
  calendarExport,
  studyMarkdown,
  textPdf,
} from "./exports.ts";
const document: VaultDocument = {
  id: "source-a",
  title: "Course",
  type: "Study Material",
  status: "Ready",
  summary: "",
  entities: [],
  pages: 1,
  date: "2026-10-13",
  confidence: 1,
  sourcePages: [
    {
      page: 7,
      text: "Submission deadline: 30 October 2026. Payment due: 02/03/2026. Example: submit by 15 November 2026. Submit by 25 December.",
    },
  ],
};

test("source dates require a complete year and unambiguous order", () => {
  assert.equal(parseDeadlineDate("30 October 2026"), "2026-10-30");
  assert.equal(parseDeadlineDate("2026/10/30"), "2026-10-30");
  assert.equal(parseDeadlineDate("13/10/2026"), "2026-10-13");
  assert.equal(parseDeadlineDate("10/30/2026"), "2026-10-30");
  for (const date of [
    "02/03/2026",
    "25 December",
    "31 February 2026",
    "2026-13-01",
  ])
    assert.equal(parseDeadlineDate(date), null);
});
test("deadline extraction retains source ID/page and sends examples and uncertain dates to review", () => {
  const dates = extractDeadlines([document]);
  assert.equal(
    dates.find((d) => d.dateText === "30 October 2026")?.due,
    "2026-10-30",
  );
  assert.equal(dates.find((d) => d.dateText === "02/03/2026")?.due, null);
  assert.equal(dates.find((d) => d.dateText === "15 November 2026")?.due, null);
  assert.equal(dates.find((d) => d.dateText === "25 December")?.due, null);
  assert.ok(dates.every((d) => d.documentId === "source-a" && d.page === 7));
});
test("an entity date absent from source text cannot become a confirmed deadline", () => {
  const dates = extractDeadlines([
    {
      ...document,
      sourcePages: [{ page: null, text: "Read chapter three." }],
      entities: [{ label: "Submission deadline", value: "30 October 2026" }],
    },
  ]);
  assert.equal(dates.length, 1);
  assert.equal(dates[0].due, null);
  assert.equal(dates[0].page, null);
});
test("submit proof of payment remains a submission and does not duplicate the matching entity", () => {
  const dates = extractDeadlines([
    {
      ...document,
      sourcePages: [
        {
          page: 1,
          text: "Payment deadline: 30 October 2026. Submit proof of payment by 2 November 2026.",
        },
      ],
      entities: [
        { label: "Payment deadline", value: "30 October 2026" },
        { label: "Submission deadline", value: "2 November 2026" },
      ],
    },
  ]);
  assert.equal(dates.length, 2);
  assert.equal(
    dates.find((d) => d.due === "2026-11-02")?.key,
    "source-a|Submission|2026-11-02",
  );
});
test("unknown source pages stay unknown rather than acquiring invented page one", () => {
  assert.equal(
    sourcePages({ ...document, sourcePages: [], rawText: "Source text" })[0]
      .page,
    null,
  );
  assert.equal(
    sourcePages({
      ...document,
      sourcePages: [{ page: 0, text: "Source text" }],
    })[0].page,
    null,
  );
});
test("quiz answer locking and progress are based on recorded selections", () => {
  const quiz: Quiz = {
    id: "quiz-a",
    spaceId: "course-a",
    documentId: "source-a",
    createdAt: "",
    questions: [
      {
        prompt: "Key?",
        options: ["A", "B", "C", "D"],
        correctIndex: 1,
        explanation: "Source",
        sourceDocumentId: "source-a",
        sourceTitle: "Course",
        sourceExcerpt: "Source",
        sourcePage: 7,
      },
    ],
  };
  const answered = answerQuestion(quiz, 0, 1);
  assert.equal(answerQuestion(answered, 0, 2).questions[0].selectedIndex, 1);
  assert.equal(
    answerQuestion(quiz, 0, -1).questions[0].selectedIndex,
    undefined,
  );
  assert.deepEqual(quizProgress([answered]), {
    answered: 1,
    correct: 1,
    rounds: 1,
  });
  assert.equal(quiz.questions[0].selectedIndex, undefined);
});
test("revision ratings schedule again in ten minutes and double recalled intervals up to thirty days", () => {
  const now = new Date("2026-10-13T10:00:00Z"),
    card = {
      id: "card",
      spaceId: "space",
      front: "Question",
      back: "Answer",
      documentId: "source-a",
      documentTitle: "Course",
      sourcePage: 7,
      sourceExcerpt: "Source",
      dueAt: "",
      intervalDays: 0,
      reviews: 0,
    };
  assert.equal(reviewCard(card, false, now).dueAt, "2026-10-13T10:10:00.000Z");
  const recalled = reviewCard(card, true, now);
  assert.equal(recalled.intervalDays, 1);
  assert.equal(recalled.dueAt, "2026-10-14T10:00:00.000Z");
  assert.equal(
    reviewCard({ ...card, intervalDays: 20 }, true, now).intervalDays,
    30,
  );
  assert.equal(dueCards([recalled], now.getTime()).length, 0);
});
test("encrypted snapshots are opaque and authenticated to the correct account", async () => {
  const key = await crypto.subtle.generateKey(
      { name: "AES-GCM", length: 256 },
      false,
      ["encrypt", "decrypt"],
    ),
    data = emptyWorkspace();
  data.chats.source = [
    {
      id: "message",
      role: "assistant",
      text: "Sensitive original source passage",
    },
  ];
  const encrypted = await encryptWorkspace("account-a", key, data);
  assert.equal(
    new TextDecoder()
      .decode(encrypted.ciphertext)
      .includes("Sensitive original"),
    false,
  );
  assert.deepEqual(await decryptWorkspace("account-a", encrypted), data);
  await assert.rejects(decryptWorkspace("account-b", encrypted));
  assert.equal(key.extractable, false);
});
test("CSV exports neutralise spreadsheet formulas and quote embedded separators", () => {
  const csv = activityCsv([
    {
      id: "activity",
      at: "2026-10-13",
      category: "Document",
      action: '=HYPERLINK("https://invalid")',
      detail: "hello,world",
    },
  ]);
  assert.ok(csv.includes('"\'=HYPERLINK(""https://invalid"")"'));
  assert.ok(csv.includes('"hello,world"'));
});
test("calendar exports preserve confirmed dates, escape content and fold long lines", () => {
  const ics = calendarExport([
    {
      id: "task",
      title: "Pay, submit; confirm\n" + "very long title ".repeat(15),
      due: "2026-10-30",
      priority: "High",
      completed: false,
    },
  ]);
  assert.ok(ics.includes("DTSTART;VALUE=DATE:20261030"));
  assert.ok(ics.includes("Pay\\, submit\\; confirm\\n"));
  assert.ok(
    ics
      .split("\r\n")
      .every((line) => new TextEncoder().encode(line).length <= 75),
  );
});
test("study exports include notes, cards and original source evidence", () => {
  const text = studyMarkdown(
    "Databases",
    [],
    [
      {
        id: "card",
        spaceId: "space",
        front: "A question",
        back: "An answer",
        documentId: "source-a",
        documentTitle: "Course",
        sourcePage: null,
        sourceExcerpt: "Original excerpt",
        dueAt: "",
        reviews: 0,
        intervalDays: 0,
      },
    ],
  );
  assert.ok(text.includes("Revision cards"));
  assert.ok(text.includes("Original excerpt"));
  assert.ok(text.includes("page unavailable"));
});
test("readable PDF export uses the bundled font and produces real multipage content", async () => {
  const previous = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(
      await readFile(
        new URL(
          "../../../public/fonts/dm-sans-latin-400-normal.woff",
          import.meta.url,
        ),
      ),
    );
  try {
    const pdf = await PDFDocument.load(
      await textPdf(
        "Résumé & revision",
        "Source paragraph with café.\n".repeat(130),
      ),
    );
    assert.ok(pdf.getPageCount() > 1);
    assert.equal(pdf.getTitle(), "Résumé & revision");
  } finally {
    globalThis.fetch = previous;
  }
});
test("answer markdown renders readable formatting while rejecting raw HTML, remote images and script links", () => {
  const html = renderToStaticMarkup(
    createElement(AnswerMarkdown, {
      text: "## Concepts\n\n**Primary key** and *foreign key*.\n\n- First\n- Second\n\n![tracking pixel](https://invalid.example/pixel.png)\n\n<script>alert(1)</script>\n\n[unsafe](javascript:alert(1))",
      openSource: () => undefined,
    }),
  );
  assert.ok(html.includes("<h3>Concepts</h3>"));
  assert.ok(html.includes("<strong>Primary key</strong>"));
  assert.ok(html.includes("<em>foreign key</em>"));
  assert.ok(html.includes("<ul>"));
  assert.equal(html.includes("<img"), false);
  assert.equal(html.includes("<script"), false);
  assert.equal(html.includes("javascript:"), false);
});
test("inline source markers resolve server citation numbers, preserve duplicate-title IDs and leave code literal", () => {
  const citations = [
    {
      number: 1,
      documentId: "document-a",
      title: "Same title",
      page: 2,
      excerpt: "First source",
    },
    {
      number: 2,
      documentId: "document-b",
      title: "Same title",
      page: 7,
      excerpt: "Second source",
    },
  ];
  const html = renderToStaticMarkup(
    createElement(AnswerMarkdown, {
      text: "Definition [SOURCE:2]. Unknown [SOURCE:9]. `Literal [SOURCE:1]`",
      citations,
      openSource: () => undefined,
    }),
  );
  assert.equal(citationByNumber(citations, 2)?.documentId, "document-b");
  assert.ok(html.includes('aria-label="Open source: Same title, page 7"'));
  assert.ok(html.includes("Source 2</button>"));
  assert.ok(html.includes("Source 9</span>"));
  assert.ok(html.includes("<code>Literal [SOURCE:1]</code>"));
  assert.equal(
    html.includes('aria-label="Open source: Same title, page 2"'),
    false,
  );
});
