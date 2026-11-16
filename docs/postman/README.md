# Folio AI API in Postman

Import `Folio-AI.postman_collection.json` and either the Production or Local environment JSON. Select that environment in Postman.

1. Set `sessionCookie` to the **value only** of a valid `FOLIO_SESSION` cookie from a signed-in Folio browser session. The cookie is HttpOnly, so use the browser’s developer tools, Application/Storage → Cookies. Keep this value private and local; do not export or commit a filled environment. The collection sends the Cookie header explicitly; disable Postman’s cookie jar for these requests if it contains another Folio session.
2. Set `documentId` to a READY document owned by that same account. You can copy its ID from the document data in your browser’s Network panel. Uploading or processing documents is outside this collection.
3. Set `question` and send **01 — Greeting**, then **02 — Ask one document**. For the follow-up request, paste the actual earlier answer into `previousAnswer`. Set `focus` if you want a quiz topic.
4. Open **Test Results** and the **Postman Console** to inspect status, total response time, actual model, and citation/question counts. Set Postman’s request timeout to **70,000 ms** so it can show server errors. `maxResponseMs` is a configurable assertion budget, initially 50,000 ms, not a promised response time.

Only these two API routes are included:

| Method | Route | Response |
| --- | --- | --- |
| POST | `{{baseUrl}}/v1/ai/ask` | Newline-delimited JSON events: `delta`/`replace`, then `done` with model and citations |
| POST | `{{baseUrl}}/v1/ai/quiz` | JSON containing questions, actual model, difficulty, requestedCount and coverage |

The production base URL includes `/api`: `https://folio-vn1g-two.vercel.app/api`. Every request supplies `X-Requested-With: FolioWeb` and the session cookie. No OpenRouter key or Supabase service key is required in Postman.

The greeting bypasses generation, so it checks authentication/connectivity only. Document-question tests require a nonempty answer, a final `done` event, an actual model and matching citations: HTTP 200 alone does not establish successful AI generation. Quiz tests check source IDs, answer indexes and four options per question; fewer questions than requested can be valid.

The current ask handler buffers the provider’s complete answer before returning NDJSON. Postman’s response time measures the total request, including authentication, evidence lookup, generation and audit work; it does not isolate provider latency or time to first token. The source currently limits ask generation to 45 seconds and quiz generation to 48 seconds inside a 60-second route budget. A deployed version may differ.

Typical errors: **401** missing/expired session; **403** missing request verification header; **400** invalid input; **404** quiz source missing/not ready; **422** insufficient quiz text; **503** provider/configuration/processing failure. A 200 ask response may also be an abstention; the grounded-answer test flags it.

Requests use the real configured provider and may add AI usage records. Send them individually while diagnosing latency. Neither the collection nor its environments contains credentials. These files are based on the local route implementations; authenticated live generation must be verified with your session and document.
