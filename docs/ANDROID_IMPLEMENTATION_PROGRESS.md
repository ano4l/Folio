# Android refinement — implementation wave 1

Date: 27 September 2026. Scope: Flutter Android application and the Next.js API it consumes. No iOS changes were made in this implementation wave. Existing unrelated work remains untouched.

## Implemented

- Account-scoped encrypted device storage for document metadata/text, individual document chats, drafts, saved answers, recently removed documents, and tasks.
- Account-generation guards prevent late document/auth/chat responses from repopulating a signed-out account. Session writes are serialized; sign-out clears local credentials while requesting server revocation.
- Separate full-height document conversations. Cross-document comparison is an explicit mode. Latest ten conversation messages are sent as context.
- Stop/retry, partial-answer preservation, saved answers, copy/share, dictation/read-aloud, keyboard-aware composer, reader-controlled follow-scroll, reduced-motion handling, and shared Markdown rendering for answers/summaries.
- Source chips and inline source links open extracted source text by document ID. New page-aware citations retain real page numbers. Legacy flattened documents do not claim page 1 as verified provenance.
- Persistent tab state, working recent-document navigation, portrait restriction removal, search, attention filter, pull-to-refresh, error/empty/loading states, confirmed deletion with undo, and restore error feedback.
- Biometric lock no longer unlocks automatically when biometrics are unavailable. The lock covers pushed routes; account change removes the previous account's navigation stack.
- Native ML Kit scan capture with crop/reorder/gallery support (up to 20 pages), PDF output, and bundled Latin-script OCR for Android images/PDFs. Processing is sequential off the Android UI thread.
- Upload stages, category persistence, 20 MB validation, honest processing outcomes, and retry processing. A stored upload whose processing fails does not invite another upload as though storage failed.
- PDF extraction preserves page boundaries. Device OCR supplies missing page text; original selectable text takes priority. Incomplete/blank-page extraction requires review. Oversized extraction is rejected instead of silently truncated. Provider-generated confidence is not represented as measured OCR confidence.
- Processing ownership/deletion checks, optimistic processing claims to limit duplicate jobs, persisted-update checks, and short-lived owner-authorized original-file URLs.
- Document-linked tasks with explicit user-confirmed dates, persisted completion, undo, correct day markers, rolling calendar bounds, and accurate overdue/date labels.
- Removed nonfunctional MFA/sharing switches and misleading claims of an immutable cryptographic device audit ledger.

## Verification

- Flutter unit/widget tests cover account isolation, stale responses, cancellation/retry, latest conversation context, task persistence, invalid API payloads, Markdown, 320/412/900-pixel layouts with large text and keyboard, upload-sheet layout, login/MFA, and the tablet rail.
- Backend tests cover page serialization, legacy text, malformed/oversized extraction, and blank-page review visibility.
- Verified: 15 Flutter unit/widget tests; four backend page tests; clean Flutter analysis; Android debug APK compilation; Next.js production build and TypeScript checks.
- Verified on the Android emulator: the real bundled OCR recognizer read the synthetic image's bursary heading and exact due date. This is native OCR evidence, not proof of real-camera quality or provider-backed end-to-end extraction accuracy.
- `mobile/integration_test/android_ocr_test.dart` runs the real Android OCR bridge against a synthetic image. It does not call the AI provider or upload private data.

## Deployment and limits

- Backend changes must be deployed with this mobile build. Existing production endpoints do not yet implement the new original-file URL or device-extraction contracts. Nothing was deployed or pushed by this task.
- Chats/tasks are encrypted **on this device**, not cross-device cloud sync. Recently removed documents are the device's known removals, not a complete server-side trash listing.
- Scanner capture depends on compatible Google Play services; first launch may download scanner components. File import remains available. Bundled OCR currently handles Latin script; handwriting, formulas, complex tables, and other scripts need further evaluation.
- On-device OCR is limited to 20 pages. Longer selectable PDFs can still be extracted on the server within the text-size limit; long scanned PDFs require splitting. Blank pages currently require review rather than being assumed harmless.
- Processing remains request-based, not a durable background job queue. No automatic task extraction, calendar sync, scheduled notification delivery, malware scanning, or cross-device chat synchronization is claimed.
- Source text opens in an in-app sheet; the original uses an external viewer via a two-minute signed URL. A full in-app page viewer/highlighting remains future work.
- Full dark theme, measured release-mode frame performance, real-camera scan QA, TalkBack exploration, accessibility contrast audit, OCR corpus accuracy, and release signing remain rollout gates. Debug APKs are not Play Store releases.

## Next wave

### Additional Android UI polish

- Interactive cards now expose Material ink feedback and a brief press response; reduced-motion mode disables the scale entirely.
- Tab switches use a short fade while retaining page state. Hidden tabs have tickers and keyboard focus disabled.
- Navigation selection, button targets, sheet/snackbar styling, and small amber-label contrast were refined without changing Folio's visual identity.
- Document search has a clear action; detail actions use an overflow menu and an explicit document-chat button.
- Chat has a focus-responsive, single-surface composer; source sheets expand from 35% to 95% of the available height for longer reading.
- Tasks are grouped by urgency, with list/calendar switching, date filtering, completed-task disclosure, and completion undo.
- Verification: 20 Flutter tests passed, including tab-state retention, reduced-motion behavior, and task list/calendar layouts at 320/412/900 logical pixels with 150% text. Debug APK rebuilt successfully. These are widget-layout checks, not native visual inspection or release-mode frame measurements.

1. Real-device camera/OCR corpus testing, cancellation/retry stress tests, TalkBack and release-mode frame profiling.
2. Durable background extraction jobs, malware screening, structured review/correction, table preservation, and in-app page highlighting.
3. User-approved extracted tasks, calendar export/reminders, study-focused summaries, and cross-device synchronization with server ownership tests.
4. Complete theme/accessibility pass and production signing/deployment verification.
