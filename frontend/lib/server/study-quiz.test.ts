import { test } from "node:test";
import assert from "node:assert/strict";
// @ts-ignore Node's native test runner needs the .ts extension.
import { generateStudyQuiz, parseSupportedQuestions } from "./study-quiz.ts";

const evidence = [
  {
    number: 1,
    page: 7,
    text: "A primary key uniquely identifies each row and cannot be null. An inner join returns matching rows.",
  },
];
const question = {
  question: "What does a primary key identify?",
  choices: ["Each row", "A database server", "A query timeout", "Every table"],
  correctIndex: 0,
  explanation: "The source says a primary key uniquely identifies each row.",
  evidenceQuote: "A primary key uniquely identifies each row",
  source: 1,
};
const options = {
  documentId: "document-a",
  title: "Database notes",
  count: 5 as const,
  difficulty: "standard",
  focus: "keys",
};

test("rejects invented quotes, invalid source numbers, duplicate choices and answer indexes", () => {
  for (const invalid of [
    { evidenceQuote: "An invented answer that is not in the source" },
    { source: 7 },
    { choices: ["Each row", " each ROW ", "Another", "Fourth"] },
    { correctIndex: -1 },
    { correctIndex: 4 },
  ])
    assert.equal(
      parseSupportedQuestions(
        JSON.stringify({ questions: [{ ...question, ...invalid }] }),
        evidence,
      ).length,
      0,
    );
});

test("keeps source-supported questions and removes duplicate prompts", () => {
  const result = parseSupportedQuestions(
    "```json\n" +
      JSON.stringify({
        questions: [
          question,
          { ...question, question: " " + question.question.toUpperCase() },
        ],
      }) +
      "\n```",
    evidence,
  );
  assert.equal(result.length, 1);
});

test("does not accept partial JSON or use reasoning text as a quiz", () => {
  assert.deepEqual(parseSupportedQuestions('{"questions":[', evidence), []);
  assert.deepEqual(
    parseSupportedQuestions(
      "I should think about the source before answering",
      evidence,
    ),
    [],
  );
});

test("limits reasoning and scales the completion allowance without losing source page metadata", async () => {
  for (const count of [3, 5, 8] as const) {
    const result = await generateStudyQuiz(
      evidence,
      { ...options, count },
      async (request) => {
        assert.equal(request.reasoningEffort, "none");
        assert.equal(request.maxOutputTokens, 2400 + count * 600);
        assert.equal(request.responseJsonSchema.type, "object");
        assert.match(request.prompt, /Page: 7/);
        return {
          text: JSON.stringify({ questions: [question] }),
          model: "actual/model",
        };
      },
      AbortSignal.timeout(1000),
    );
    assert.equal(result.model, "actual/model");
    assert.equal(result.questions[0].sourcePage, 7);
    assert.equal(result.questions[0].sourceDocumentId, "document-a");
    assert.equal(
      result.questions[0].options[result.questions[0].correctIndex],
      "Each row",
    );
  }
});

test("repairs an incomplete provider completion but never accepts unsupported fallback content", async () => {
  let calls = 0;
  const result = await generateStudyQuiz(
    evidence,
    options,
    async () => {
      if (++calls === 1)
        throw new Error("OpenRouter returned no complete usable response");
      return {
        text: JSON.stringify({ questions: [question] }),
        model: "recovered/model",
      };
    },
    AbortSignal.timeout(1000),
  );
  assert.equal(calls, 2);
  assert.equal(result.questions.length, 1);
  await assert.rejects(
    generateStudyQuiz(
      evidence,
      options,
      async () => ({
        text: JSON.stringify({
          questions: [
            {
              ...question,
              evidenceQuote: "Unsupported facts never become a quiz",
            },
          ],
        }),
        model: "bad/model",
      }),
      AbortSignal.timeout(1000),
    ),
    /source-supported/,
  );
});

test("does not layer content retries over provider transport failure or cancellation", async () => {
  let calls = 0;
  await assert.rejects(
    generateStudyQuiz(
      evidence,
      options,
      async () => {
        calls++;
        throw new Error("OpenRouter request failed (429)");
      },
      AbortSignal.timeout(1000),
    ),
    /429/,
  );
  assert.equal(calls, 1);
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(
    generateStudyQuiz(
      evidence,
      options,
      async () => {
        assert.fail("An aborted request must not call the provider");
      },
      controller.signal,
    ),
    /timed out/,
  );
});
