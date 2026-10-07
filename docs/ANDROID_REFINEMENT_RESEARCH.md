# Folio Android: product research and refinement roadmap

Research date: 27 September 2026.

## Recommendation

Build Folio around one repeatable outcome: a student understands a document, verifies the relevant evidence, and knows the next action to take. The most valuable refinement is completing this journey across Documents, Chat, and Deadlines.

Keep Folio's warm paper background, teal accent, and restrained editorial headings. Give Android users familiar navigation, reliable Back behavior, readable content, and a composer that stays comfortable above the keyboard. Reduce nested cards and decoration around long answers.

This is a research and planning deliverable. Application code was inspected, not changed during this research. Findings below distinguish directly observed implementation gaps from proposed designs. No emulator, live account, production provider, or physical-device UX test was performed in this research pass. Existing build claims are not evidence that these flows are complete.

## Research basis

The review covered the Flutter state, API client, app shell, chat, documents, upload, dashboard, deadlines, security, theme, Android configuration, current widget tests, product requirements, and the server extraction/chat contracts.

External research used primary documentation from Android, Flutter, Google Design, Google PAIR, Google Drive, Google's Notebook help, Adobe Acrobat, and ML Kit. Platform recommendations are translated into Flutter work; adopting Android interaction patterns does not require rewriting the app in Kotlin/Compose.

The feature priorities and effort bands below are product/engineering judgment. They are not validated demand, a calendar estimate, or a promise of measurable retention gains.

## 1. What the current implementation establishes

Useful foundations already exist:

- Live password/email-OTP/session and document API integrations.
- A document-keyed chat map and a separate all-documents conversation.
- Streamed AI responses through the existing NDJSON API.
- A direct document-to-chat entry point.
- Secure session-cookie storage and local biometric app locking.
- A compact navigation bar and a wider-screen navigation rail.
- A distinctive visual identity worth retaining.

The previous refinement is a starting point. It does not yet constitute a complete formatting, interaction, or reliability pass.

### Confirmed code findings and their implications

| Priority | Finding | Evidence | Recommended correction |
| --- | --- | --- | --- |
| P0 | Logout clears documents/user but leaves chats, active chat scope, deleted documents, deadlines, and audit entries in the same AppState instance. | `mobile/lib/services/app_state.dart`, `logout`, `_chatByDocument` | Clear account-scoped state on logout/session expiry; scope persisted data by authenticated user; cancel or ignore responses belonging to an old session. This is a potential cross-account disclosure path inferred from code, not a reproduced exploit. |
| P0 | Chat history is memory-only; a process restart loses it. | `app_state.dart`, `_chatByDocument` | Store conversations by user ID, document ID and document version; define deletion/retention behavior. Persist drafts as well as completed messages. |
| P0 | The client sends `history.take(10)`, which selects the oldest messages once a conversation exceeds ten entries. | `mobile/lib/services/api_service.dart:235` | Send the latest relevant turns within a context budget. Keep the full transcript available to the user. |
| P0 | The assistant renderer handles heading prefixes and basic bullets, but not inline bold, tables, links, code or source tokens. Summary text uses a plain Text widget. | `mobile/lib/screens/ask_ai_screen.dart:471`; `documents_screen.dart:552` | Use a shared structured renderer for assistant answers and summaries. Test incomplete Markdown during streaming. |
| P0 | Every chat rebuild schedules a scroll to the bottom. A single global `aiTyping` flag governs all conversations. | `ask_ai_screen.dart:110`; `app_state.dart:37` | Follow incoming text only when the user is near the end. Give each conversation its own request status and a Jump to latest action. |
| P0 | Document chat uses the same global scope selector, and the composer has a fixed 90px bottom gap while the transcript has 120px bottom padding. | `documents_screen.dart:392`; `ask_ai_screen.dart:162,317` | Bind a document conversation explicitly to its document; make cross-document mode deliberate. Use actual keyboard/navigation/safe-area insets. Runtime overlap must still be tested. |
| P0 | Citation mapping discards the server document ID; UI matches titles and shows a snackbar rather than opening the cited passage. | `app_state.dart:267`; `ask_ai_screen.dart:237` | Preserve stable IDs and source metadata, then open a source preview directly. Duplicate document titles must not break routing. |
| P0 | Extraction merges text into a document-level value and stores `page_number: 1`. | `frontend/lib/server/document-processing.ts:21,37` | Retain page boundaries, passages and version IDs before promising accurate page-level citations. Bounding boxes are a later OCR extension. |
| P0 | JPEG/PNG uploads are accepted, but the inspected processor returns no extracted text for these formats; files without text become REVIEW_REQUIRED. The client discards the process response and reports processing success. | `document-processing.ts:16,51`; `api_service.dart`, `uploadDocument`; `documents_screen.dart:250` | Distinguish Uploaded, Processing, Ready, Needs review, and Failed. Add real OCR or provide an explicit rescan/retry path. |
| P0 | Calendar eventLoader returns every pending deadline for every date. Calendar bounds are fixed to 2026 and several date labels are blank templates. | `mobile/lib/screens/deadlines_screen.dart:57,75,136,196` | Use typed due dates, date-specific events, correct labels, and rolling calendar bounds. |
| P0 | Deadlines start empty, are not populated by the inspected refresh flow, and completion only mutates memory. | `app_state.dart`, `deadlines`, `refreshDocuments`, `resolveDeadline` | Add a persistent obligation pipeline. Distinguish No deadlines found from Not processed or Could not load. |
| P1 | Recent-document taps set selectedDoc but do not navigate away from Home. | `mobile/lib/screens/dashboard_screen.dart`, `_RecentDocuments`; `main_shell.dart` | Use a central document route reachable from Home, Search, Chat citations and notifications. |
| P1 | Vault has no search/filter control or explicit loading/error handling; AppState already exposes those states. | `documents_screen.dart:12`; `app_state.dart:24` | Add search, filter chips, sort, refresh and contextual error/empty states. Preserve content during a failed refresh. |
| P1 | Upload category is selectable but is never passed to uploadDocument. | `documents_screen.dart:206,241,347`; `api_service.dart:175` | Either persist the selection end to end or present category as detected after processing, with a supported correction action. |
| P1 | Delete starts an asynchronous request without awaiting it and immediately reports success. | `documents_screen.dart:448` | Await confirmation or implement optimistic deletion with rollback; expose Undo backed by restore. Handle failure visibly. |
| P1 | Tab switching removes the old screen after AnimatedSwitcher finishes; drafts and local scroll state are not preserved by the shell. | `mobile/lib/screens/main_shell.dart:89` | Preserve tab state deliberately and store chat drafts per conversation. |
| P1 | Only a light theme is configured; startup requests portrait-only orientation. | `mobile/lib/main.dart:14,32` | Add semantic light/dark colors and responsive layouts that survive rotation and resizing. |
| P1 | Security controls overstate their implementation: MFA toggle is a no-op, sharing is a local boolean, and the displayed audit list is local despite cryptographic/immutable wording. | `security_screen.dart:71,148,157`; `app_state.dart:344` | Show enforced MFA as a status; implement scoped sharing before offering it; describe the audit history accurately. |
| P1 | Biometric setup calls itself a passkey and uses Face ID terminology on Android; unavailable biometrics can unlock an already locked app. | `security_screen.dart:102`; `main.dart:86,106` | Use Android terminology, distinguish local unlocking from server sign-in, and design explicit recovery when biometric availability changes. |
| P1 | OCR confidence is not a measured OCR probability in this path: the summary model produces it, and missing client values default to 90. | `document-processing.ts:62`; `mobile/lib/models/document.dart:45` | Represent unknown confidence as unknown; prioritize source evidence and reviewable fields. Do not turn a self-reported score into an assurance of correctness. |
| Before release | Release build currently selects the debug signing configuration. | `mobile/android/app/build.gradle.kts` | Set up production signing and verify install/update behavior before public distribution. |

The existing test file covers login, MFA rendering and the wide navigation rail. It does not establish chat isolation, citation routing, keyboard behavior, streaming recovery, or deadline correctness.

## 2. Product benchmarks and what to adopt

| Benchmark | Relevant evidence | Folio interpretation |
| --- | --- | --- |
| Adobe Acrobat mobile | Citations open source references with document, section and page information. | Make verification a one-tap interaction that preserves the user's place in chat. [Adobe source citations](https://helpx.adobe.com/acrobat/mobile/pdf-spaces/view-citations.html) |
| Google's Notebook product | Source selection, citation navigation, retained private chat history, response-length controls and saving answers as notes are documented. Mobile availability can differ. | Adopt explicit conversation scope, saved answers and concise/detail options. Do not assume every documented web feature exists on mobile. [Google chat documentation](https://support.google.com/gemininotebook/answer/16179559?hl=en) |
| Google Drive Android | A dedicated scan workflow brings paper documents into the library. | Offer Scan alongside Import; provide crop, rotate, review and a clear save step. [Drive scanning](https://support.google.com/drive/answer/3145835?co=GENIE.Platform%3DAndroid&hl=en) |
| Android adaptive layouts | List-detail and supporting-pane arrangements suit content with related context. | On tablets, show the document beside its chat or source preview. On phones, use a dedicated conversation route. [Canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts) |
| Google PAIR | Confidence displays can mislead; understandable limitations and recovery affect trust. | Prefer visible evidence and actionable review states over unexplained percentages. [Trust](https://pair.withgoogle.com/guidebook-v2/chapter/explainability-trust/) · [Failure recovery](https://pair.withgoogle.com/guidebook-v2/chapter/errors-failing/) |

Folio's product opportunity is the student-specific transition from evidence to action. A general document chatbot can summarize a letter; Folio should help the student confirm what they must submit, when, and which document proves it.

## 3. The target document and chat experience

### Document workspace

Use three clearly named destinations within a document: Overview, Original, and Chat. Keep document title and processing/review state visible. On a phone, long conversations deserve a full-height route; a sheet can provide a short preview, then expand. The system Back action should reverse the current navigation step and retain scroll position.

Overview should answer, in order:

1. What is this document? One plain-language sentence.
2. What matters? A short summary and a small number of sourced facts.
3. What do I need to do? Only actions that are actually supported by the document.
4. When? Important dates, including the year and the original wording when ambiguous.
5. What needs checking? Missing fields, unclear scans or conflicting details.

Avoid filling empty sections with guessed dates or boilerplate actions. Keep the original text available. Users should be able to correct an extracted value without overwriting the original evidence.

Illustrative layout, not actual student data:

```text
Bursary agreement                         More
Overview              Original             Chat

Your bursary at a glance
One short explanation of the agreement.

Key facts
Award amount    [value]                 Source
Renewal date    [date]                  Source

Next actions
Submit [document] by [confirmed date]    Review

Ask about this agreement
```

### Conversation scope and continuity

- Give every document a stable default conversation, its own draft and reading position.
- Show the document title in the conversation header, not just a dropdown choice.
- Keep All documents as an explicit comparison mode with a visible source-selection step.
- Store messages against a user, conversation and document version. A reprocessed document should mark older answers as based on the earlier version.
- Allow clearing history with an explicit action; deleting a document should have defined effects on associated answers and cached source files.
- Do not send user-facing failure messages or incomplete streaming fragments back as authoritative assistant history.

### Make answers feel less blocky

- Render assistant answers directly on a calm reading surface; reserve compact tinted bubbles for user messages.
- Use a shared Markdown/structured-content renderer with semantic headings, paragraphs, bold, numbered/bulleted lists, safe links, tables and inline citations.
- Keep raw user prompts literal. Formatting a user's pasted text as assistant Markdown can change its meaning.
- Support selectable/copyable text and copy/share output that retains readable source references.
- On phones, give tables their own horizontal scrolling region or a label-value layout; the full screen should not scroll sideways.
- Allow an unfinished emphasis marker or citation token during streaming without causing visible markup flashes or repeated layout jumps.
- Prefer a short answer first, followed by relevant detail. Offer Explain simply, Show details, List actions and Draft a question for the funding office.
- Use document-specific suggestions: renewal conditions for a bursary, line-item explanation for a fee statement, required evidence for an appeal.

### Composer and streaming behavior

- A multiline composer grows to a bounded height, with a visible send button and persistent document scope.
- Drafts survive navigation, sheet dismissal, app backgrounding and transient failures.
- A send action is accepted exactly once. If a request cannot be accepted, preserve the draft.
- While generating, show Stop. When interrupted, preserve partial text, label it incomplete, and offer Retry.
- Track request state per conversation. Returning to another document must not show an unrelated typing indicator.
- Autoscroll only if the reader is already near the bottom. Scrolling upward pauses following; Jump to latest restores it.
- Batch streaming UI updates and rebuild the active transcript rather than the entire app shell for every token.
- Announce response completion to TalkBack without speaking every streamed token.
- Dictation needs visible listening, stop/cancel, permission-denied and unavailable states. Reading aloud needs an active-message indicator and Stop, with cleanup on navigation.

### Source verification

Tap an inline citation to see the source title, page when known, quoted passage and Open original action. On tablets, use a supporting pane; on phones, a preview sheet that returns to the exact answer position.

Prerequisites: stable source IDs, preserved citation-token mapping, page/passage extraction, document versions, and an authorized original-file access path. The current API returns document IDs, titles and page numbers but not passage boxes. Do not draw highlights or invent page numbers when provenance is unavailable.

## 4. Screen-by-screen interaction pass

| Surface | Refinement | Acceptance condition |
| --- | --- | --- |
| Home | Lead with the next confirmed obligation, documents needing review, and resume reading/chat. Keep aggregate metrics secondary. | A recent document opens directly; no empty state reports success when data failed to load. |
| Vault | Search title and extracted content; filter by type, year and processing state; sort by recent/name; show concise text snippets. Add batch actions only after single-document flows are reliable. | Search/filter/sort work together, empty matches have a clear reset action, and refresh retains existing content. |
| Upload | Import or Scan; file preview; supported-format/size checks; duplicate detection; distinct upload and processing stages; retry failed processing without re-uploading. | A review-required document is never announced as Ready. The chosen category is persisted or clearly described as automatic. |
| Document | Overview/Original/Chat; text selection; searchable original; page position; source-linked facts; contextual actions. | A fact can be checked against evidence and the user can return without losing their place. |
| Chat | Flat assistant typography, scoped draft/history, stable streaming, response actions and citation preview. | Switching documents or accounts cannot mix content. Long replies, offline failure and a raised keyboard remain usable. |
| Deadlines | Upcoming/Overdue/Completed; calendar selection shows only that day's items; review extracted dates; reminder controls; completion and Undo. | Status survives restart; uncertain/relative dates require resolution; duplicates are handled. |
| Security/account | Accurate labels for MFA, biometric locking, sessions and data access; export/delete flows when supported; sharing scope rather than a generic switch. | Every enabled control changes real persisted behavior or explicitly opens setup. |
| Navigation | Consider Home, Documents, Chats and Tasks as four main destinations; move Security into account/settings. Validate discoverability before adopting. | Android Back and predictive Back work, tab drafts survive, and existing functions remain reachable. |

Android's Back guidance and edge-to-edge rules make navigation and keyboard/system insets part of the acceptance criteria. Edge-to-edge is enforced on Android 15+ when targeting SDK 35+, so fixed bottom spacers are not a reliable layout strategy. [Flutter predictive Back](https://docs.flutter.dev/release/breaking-changes/android-predictive-back) · [Android insets](https://developer.android.com/develop/ui/views/layout/edge-to-edge)

## 5. New features ranked by value

Effort bands are relative: S = localized change; M = multiple screens/services; L = backend, extraction or platform work plus end-to-end validation. A band is not a delivery-time estimate.

| Rank | Addition | Why it fits Folio | Effort and dependency |
| --- | --- | --- | --- |
| 1 | Confirmed action checklist | Turns a document into something the student can complete. Each action retains source, date and completion status. | L; typed obligations, persistence, evidence and review flow. |
| 2 | Source-linked PDF reader | Makes funding facts verifiable without leaving the task. | L; authorized file access and page/passage provenance. |
| 3 | Saved chats and answers | Lets students return to explanations and keep important answers with their sources. | M–L; account isolation, document versions, retention and storage. |
| 4 | Search and semantic filters | Quickly retrieves a particular award, balance or renewal clause. Start with ordinary text search; measure the need for semantic search. | M; full-text availability and indexing strategy. |
| 5 | Share to Folio | Import a PDF/image from another Android app using the system Sharesheet, then review before upload. | M; Android intent handling, permitted content URI access, file validation and auth recovery. |
| 6 | Scan paper documents | Supports letters, photographed statements and multipage paperwork. | L; scanner integration plus actual OCR and review states. |
| 7 | Reliable reminders | Helps students act before confirmed deadlines; offers quiet hours, snooze and calendar export. | L; persisted obligations, permissions, scheduling and timezone tests. |
| 8 | Useful offline reading | Previously downloaded originals, summaries and saved answers remain readable; drafts can be prepared offline. | L; protected account-specific cache, explicit availability and sync conflict policy. Live AI remains network-dependent. |
| 9 | Compare document versions | Shows changed amounts, deadlines and clauses, with both sources visible. | L; version model, extraction quality and structured diff. Never sum overlapping awards automatically. |
| 10 | Application checklist and evidence pack | Collects a student-confirmed set of required documents and exports a reviewed package. | M–L; user-owned requirements, secure export and no assumption that the pack is institutionally accepted. |
| 11 | Plain-language glossary and reviewed translations | Explains terms such as conditional funding or renewal declaration; translations retain the original beside them. | M–L; terminology review, localization and translation evaluation. Select languages through student research. |
| 12 | Native passkey sign-in | Could reduce repeated password/OTP friction while keeping recovery paths. | L; Android Credential Manager, domain association, release certificate and existing server challenge integration. |

The Android Sharesheet supports receiving files via intents; preserve a review step before importing. [Receiving shared content](https://developer.android.com/develop/ui/compose/sharing/receive)

ML Kit offers an on-device scanning flow, but requires Google Play services, a first-use download, and supported device resources. Keep ordinary file import as a fallback. Scanning creates the source image/PDF; it does not by itself complete Folio's OCR, extraction or AI pipeline. [Scanner overview](https://developers.google.com/ml-kit/vision/doc-scanner) · [Scanner requirements](https://developers.google.com/ml-kit/vision/doc-scanner/android)

For offline functionality, define local/server responsibilities and reconcile edits explicitly. WorkManager is an option for persistent deferred Android work; it is not a guarantee of an exact reminder delivery time. [Flutter offline patterns](https://docs.flutter.dev/app-architecture/design-patterns/offline-first) · [Android persistent work](https://developer.android.com/develop/background-work/background-tasks/persistent)

Ask for notification permission when the student enables a reminder, and keep the task visible when permission is declined. [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission)

Passkeys require an actual server authentication ceremony. A successful local biometric unlock is a different operation. [Android passkey sign-in](https://developer.android.com/identity/passkeys/sign-in-with-passkeys)

## 6. Visual and motion direction

Use Material components and behavior while retaining Folio's identity. Google describes Material 3 Expressive as grounded in substantial design research; that supports deliberate hierarchy and emphasis, not making every element animated. Folio still needs its own user testing. [Google's design research](https://design.google/library/expressive-material-design-google-research)

Proposed design rules:

- Teal identifies primary actions; amber identifies items needing review; red is reserved for actionable errors/overdue states. Add words/icons so color is never the only signal.
- Keep the editorial font for short page titles. Use a readable body face for document content and AI answers.
- Start with 16sp body copy, comfortable line height and a small consistent type scale; test large Android text settings rather than fixing everything to small sizes.
- Use spacing and headings before adding another card or border. Source previews and grouped facts can be cards; entire conversations do not need stacked boxes.
- Introduce semantic colors for surfaces, content, outlines and status before adding dark mode. Converting only the Scaffold background will leave unreadable components.
- Use short state transitions and gentle container changes. Suggested starting values are 120–180ms for control feedback and 200–280ms for larger transitions; these are design hypotheses, not platform mandates.
- Respect disabled/reduced animations. Avoid per-token haptics, infinite decorative pulses and keyboard jumps.
- Give tablets a document/chat split and compact windows a single focused pane. Preserve state during resize and folding.

Accessibility targets should include 48dp interactive areas, readable contrast and meaningful labels. Confirm with TalkBack, the Android Accessibility Scanner, and Flutter's guideline tests; appearance in screenshots cannot establish these properties. [Android accessibility](https://developer.android.com/guide/topics/ui/accessibility/apps.html) · [Flutter accessibility tests](https://docs.flutter.dev/ui/accessibility/accessibility-testing)

## 7. Suggested delivery order

### Wave 1: repair the foundations

Fix account-state cleanup and obsolete in-flight responses; use recent chat history; isolate request state and drafts; correct calendar mapping, metadata and false success messages; fix direct navigation; remove unsupported controls/claims; define unknown confidence correctly.

Exit: critical account/stream/navigation/date scenarios pass, and the visible interface accurately reflects available behavior.

### Wave 2: complete the conversation and reading experience

Build the shared answer/summary renderer, stable scrolling, keyboard-aware composer, persistence, clear conversation selection, stop/retry, and readable source previews using the provenance actually available. Add vault search and clear processing/review states.

Exit: a student can open a document, ask follow-ups, navigate away, return, and verify the answer without losing context or seeing raw formatting tokens.

### Wave 3: connect evidence to actions

Implement page-aware extraction/OCR, original-file viewing, confirmed obligations, reminders and source-backed completion. Add Scan and Share to Folio once processing failures and review states are handled.

Exit: import → processing → review → explanation → confirmed task → reminder → completion works with persistence and recoverable failures.

### Wave 4: broader polish and useful expansion

Finish dark appearance, tablet/landscape layouts, offline cache, version comparison, evidence packs, language support and optional native passkeys. Complete release signing and device validation before public distribution.

Exit: the agreed Android device/accessibility matrix passes and new features have measurable task value.

Defer autonomous submissions/payments, automatic institution contact, broad web-search answers mixed into private-document chat, podcast generation, elaborate gamification, and a full PDF editing suite. These either exceed Folio's stated scope or add substantial complexity before the core journey is dependable.

## 8. How to validate the refinement

### Technical and interaction checks

- Account A → logout → account B shows no previous chats, trash, audit or deadline entries. Repeat during an active response and a network failure.
- Document A → B → A preserves independent messages/drafts; same-titled documents route correctly; deleting a document has defined chat/citation behavior.
- Conversations exceeding ten messages still answer recent follow-ups correctly.
- Offline mid-response, timeout, invalid stream data, session expiry and a provider replacement response produce recoverable states. Partial text is never silently treated as a completed answer.
- Long answers, nested lists, partial bold tokens, tables, citations and links render without raw control syntax or overflow.
- Opening the keyboard, using landscape/split screen, resizing, and increasing font size do not hide the composer or Send/Stop controls.
- Calendar markers match actual dates; overdue/today/unknown/relative dates behave correctly; rescheduling and completion survive restart.
- Import a born-digital PDF, image-only PDF, multipage photo scan, DOCX, unreadable page, unsupported file, large file and duplicate. Each reaches an accurate state with recovery options.
- Citation tests verify supporting content, not merely whether a valid source ID exists. Include contradictory letters, absent facts and instructions embedded in document text.
- Light/dark appearance, TalkBack reading order, action labels and non-color status distinctions pass.

Use profile-mode measurements on representative Android hardware. Flutter describes approximately 16ms per frame at 60Hz; 120Hz has a tighter ~8.3ms budget. Measure streaming and scrolling rather than inferring smoothness from animation code or a debug build. [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)

Suggested device matrix: compact phone, mainstream phone, lower-memory/older device within the supported range, tablet or foldable, gesture and three-button navigation, large text, keyboard-open, offline/intermittent connection, and supported old/new Android API levels. Include no-Google-Play-services fallback if scanning is in scope.

### Small student research study

Recruit a small, diverse exploratory cohort, for example 6–8 students; this identifies usability problems but is not statistically representative market validation. Use synthetic or consented redacted paperwork.

Ask participants to import a funding letter, find a renewal condition, verify a quoted amount, identify a required action, set a reminder, resume a document conversation, and recover from a failed scan. Observe hesitation and wrong turns before asking for aesthetic preferences.

Measure time and success for locating an obligation, citation-verification success, recovery without assistance, draft/history retention, perceived clarity, and whether participants can distinguish a source fact from an AI suggestion. Track technical latency and failures without collecting raw document/chat text by default.

The desired outcome is dependable comprehension and follow-through. More messages sent or more time in the app should not be treated as success on their own.
