# Folio frontend implementation plan

## 1. Frontend responsibilities

The Next.js App Router frontend owns presentation, navigation, user interaction, accessibility, and API orchestration. It must not become a document-processing service or a place where source file bytes are persisted.

The browser should receive authorised metadata and short-lived URLs from the API. It should upload source bytes directly to object storage, render processing state from API events or polling, and display extraction evidence returned by trusted backend services.

## 2. Current prototype

The current TypeScript experience in `src/components/FolioApp.tsx` recreates the supplied UI and includes:

- Credentials and MFA prototype screens.
- Dashboard statistics, active tasks, and recent documents.
- Document vault list with upload modal.
- Document detail view with AI summary, entities, visual preview, OCR, and JSON tabs.
- Grounded Q&A screen with simulated citations.
- Deadline timeline with completion state.
- Security controls and searchable audit ledger.
- Responsive mobile bottom navigation, mobile detail tabs, profile menu, and toast feedback.

Prototype state is intentionally local and simulated. It must be replaced incrementally, not all at once.

## 3. Application structure

### App shell

- `app/layout.tsx` provides document metadata, fonts, global CSS, and root providers.
- `app/page.tsx` mounts the application entry point.
- `src/components/FolioApp.tsx` currently contains the prototype shell; split stable areas into feature components as API integration grows.
- `app/globals.css` contains design tokens, component styles, desktop breakpoints, and mobile-specific behaviour.

### Recommended feature boundaries

- `features/auth`: OIDC callback state, session bootstrap, sign-out, and authorised route handling.
- `features/dashboard`: summary cards, upcoming deadlines, recent documents, and quick actions.
- `features/documents`: list, filters, upload flow, detail view, preview, OCR, and extraction evidence.
- `features/questions`: question composer, retrieval answer, citations, confidence, abstention, and feedback.
- `features/deadlines`: candidate review, edits, completion, dismissal, and reminders.
- `features/security`: consent, audit events, export, deletion request, and session controls.
- `lib/api`: typed request functions, error normalisation, auth headers, and request IDs.
- `lib/validation`: client-side file and form validation shared with tests.

## 4. Navigation and route model

The initial shell can remain a client-side screen switcher, but production routes should support deep links, browser navigation, refresh, and access checks:

- `/` — dashboard.
- `/documents` — authorised document list and filters.
- `/documents/[id]` — document detail and source evidence.
- `/ask` — grounded questions and conversation history.
- `/deadlines` — obligations and actions.
- `/security` — consent, audit, export, and deletion controls.
- `/auth/callback` — OIDC callback handling if the frontend participates in the flow.

A selected document must be addressable by ID, but the UI must show a generic not-found state for both missing and unauthorised records.

## 5. Design system and interaction rules

- Ink navy `#101A2B` is used for navigation, headings, and high-contrast actions.
- Teal `#0E7C74` communicates primary actions, trust, and grounded states.
- Amber `#C97A2B` communicates deadlines and attention, never destructive errors.
- Warm paper `#F7F6F1` provides the canvas; white cards establish hierarchy.
- Fraunces is reserved for editorial headings; DM Sans is used for interface text; DM Mono is used for extracted values and JSON/OCR views.
- Every destructive or privacy-sensitive action requires an explicit confirmation and explains the consequence.
- Every asynchronous action shows an immediate state, progress where possible, failure recovery, and a non-blocking status message.

## 6. API integration plan

Create typed API clients for:

- `GET /api/me` — current user, institution, roles, and consent capabilities.
- `GET /api/documents` — paginated authorised metadata with filters.
- `POST /api/documents/upload-url` — signed upload URL and upload constraints.
- `POST /api/documents` — complete upload and create processing record.
- `GET /api/documents/:id` — summary, entities, processing state, source references, and preview URL.
- `GET /api/documents/:id/text` — authorised OCR text, if enabled.
- `POST /api/questions` — grounded answer, citations, confidence, and abstention reason.
- `POST /api/questions/:id/feedback` — helpfulness and citation feedback.
- `GET /api/deadlines` — sorted obligations and source evidence.
- `PATCH /api/deadlines/:id` — confirm, edit, complete, or dismiss an obligation.
- `GET /api/audit-events` — paginated current-user audit history.
- `GET/POST/DELETE /api/consents` — create, list, and revoke scoped sharing.

Normalise errors into `UNAUTHENTICATED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION`, `RATE_LIMITED`, `PROCESSING_FAILED`, and `SERVER_ERROR` so each screen can render consistent recovery guidance.

## 7. State strategy

- Use local component state for ephemeral UI state such as open menus, active tabs, hover highlights, and modal visibility.
- Use a server-state library or a documented fetch/cache layer for documents, questions, deadlines, audit events, and session data.
- Invalidate document and deadline queries after upload completion or extraction updates.
- Use optimistic updates only for reversible actions such as deadline completion; revert on API failure.
- Persist no source file content in local storage, browser history, analytics payloads, or error reports.
- Cancel stale requests when users navigate away or submit a newer question.

## 8. Upload and processing UX

1. Validate file extension, MIME type, size, and empty-file conditions in the browser.
2. Request constraints and a signed URL from the API.
3. Upload directly to object storage with progress and cancellation where supported.
4. Notify the API that upload completed and receive the document ID.
5. Poll or subscribe to processing state with backoff.
6. Display each processing phase without claiming success before extraction is ready.
7. On failure, show the safe error category, preserve retry context, and never expose worker internals or file contents.

## 9. Q&A UX

- Show the question, answer, confidence, and each citation as separate accessible elements.
- Make citations open the relevant document and page/passage.
- Use a clear abstention panel when evidence is missing or contradictory.
- Never display a generic “AI is correct” message; explain that Folio is assisting from the student's documents.
- Add feedback controls that do not expose the full prompt or answer to third-party analytics.
- Keep conversation history scoped to the current user and retention policy.

## 10. Responsive behaviour

- Desktop uses the sidebar and multi-column workspace.
- Tablet collapses sidebar labels while preserving navigation icons and readable content widths.
- Mobile replaces the sidebar with a fixed bottom tab bar and reserves content space for it.
- Document detail uses a segmented mobile switch between extracted data and source document rather than squeezing both panels together.
- Long document titles and citation chips truncate or scroll without causing horizontal page overflow.
- Upload, consent, deletion, and audit dialogs must fit narrow viewports and remain keyboard accessible.

## 11. Accessibility requirements

Use semantic landmarks, heading hierarchy, labelled form controls, visible focus states, keyboard-operable dialogs, `aria-live` status announcements for processing/toasts, and sufficient contrast for urgency colors. Ensure icon-only buttons have accessible names, tab controls expose selected state, modal focus is trapped and restored, and the document preview has a text alternative.

## 12. Frontend testing

- Unit-test file validation, error mapping, deadline formatting, citation rendering, and permission-aware navigation.
- Component-test upload states, empty/error/retry states, mobile tabs, profile sign-out, and Q&A abstention.
- End-to-end test sign-in mock, upload-to-ready flow, document isolation, grounded answer citations, deadline completion, consent revocation, and responsive navigation.
- Run build, type-check, lint, and accessibility checks in CI for every pull request.

## 13. Delivery sequence

1. Stabilise the current prototype and extract reusable components.
2. Add API client types and session bootstrap behind a feature flag.
3. Connect document list/detail and signed upload flow.
4. Connect processing states, extraction evidence, and deadlines.
5. Connect grounded Q&A and feedback.
6. Add security, consent, audit, export, and deletion views.
7. Add automated tests, accessibility review, performance budgets, and production telemetry.

