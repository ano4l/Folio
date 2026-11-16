# Web App

The web app uses Next.js App Router, React, and TypeScript. `app/page.tsx` mounts `src/components/FolioApp.tsx` for authentication, then `src/components/workspace/Workspace.tsx` for the signed-in app. Shared styles are in `app/globals.css`; fonts are bundled under `public/fonts/`.

## API

Route handlers under `app/api/v1/` handle authentication, passkeys, documents, and AI requests. Server helpers in `lib/server/` manage sessions, provider calls, extraction, and evidence formatting.

Browser mutations send `X-Requested-With: FolioWeb`. Requests use the Folio session cookie; server routes check document ownership before reading or changing records. Provider credentials and the database service-role key stay on the server.

Uploads go directly to private storage using a signed upload URL. The API then extracts readable content and generates a summary. Upload activity remains visible while the user works elsewhere, with delayed retries for transient processing failures. Unreadable pages still need review.

Questions use stored document text and return source references. Quiz requests accept 3, 5 or 8 questions, difficulty and an optional focus topic. The server checks every question's choices, answer key, document identity and exact source excerpt before returning it. `OPENROUTER_QUIZ_MODEL` and `OPENROUTER_QUIZ_FALLBACK_MODEL` select quiz providers independently of the general AI model. A provider availability error permits one fallback within the same request timeout; authentication failures do not. Quizzes disable optional model reasoning to reserve the output budget for questions. Neither provider failure nor unsupported output is replaced with invented questions.

## Workspace

The web workspace includes course sources, notes and exports, scored quizzes, revision cards, exam plans, document reading and search, source-derived deadlines, a calendar, and local PDF tools. PDF merge, page extraction/removal/rotation, image or text conversion, and DOCX paragraph conversion run in the browser. DOCX conversion does not preserve Word layout.

## Client State

Original documents and their metadata come from the shared API. Courses, notes, cards, quizzes, chat history, tasks, favorites, recycle-bin references and activity are stored in account-bound, encrypted IndexedDB. They survive reloads but do not sync between browsers or to the mobile workspace. Clearing site data removes this local workspace; export anything that needs a separate backup.

The mobile client has its own encrypted device workspace. Native scanning, biometric app lock, dictation and OS sharing remain platform-specific. Web passkeys use the browser's WebAuthn support; the Security screen distinguishes this from a native app lock.

See [development](DEVELOPMENT.md), [deployment](VERCEL_SUPABASE.md), and [testing](TESTING.md).

