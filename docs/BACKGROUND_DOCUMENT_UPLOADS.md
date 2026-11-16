# Document uploads and automatic summaries

The mobile upload sheet starts an account-scoped job and closes immediately.
Users can navigate between pages while upload, extraction, and summarisation
continue. Documents shows each file's current stage and result; the toolbar
upload icon opens the same activity list from other main tabs. Study imports
and PDFs saved from document tools use the same workflow.

After storage confirms an upload, summarisation runs automatically. Temporary
AI failures trigger up to three processing attempts against the same document
ID, with 30- and 90-second backoff, preserving device-extracted pages. Pending
summaries and temporary AI failures are also picked up automatically after
sign-in or biometric unlock. If a request times out while the server
is still processing, the app polls its status before retrying. A stale server
processing lease can be reclaimed after its 120-second timeout. Unreadable
pages remain a review state; authentication and validation failures stop.

These jobs continue while navigating within Folio. They are in-memory work,
not an iOS background-transfer service or a durable server queue. Keep Folio
open until upload and processing finish. Suspending or terminating the app
can interrupt work; already confirmed originals remain in the vault.

Uploads now offer 29 suggested categories covering study, academic records,
funding, finance, identity, work, contracts, housing, health, insurance,
travel, correspondence, and other documents. The default is Document. The
metadata editor also accepts custom categories. Existing funding categories
remain available, and unknown categories display their own name on mobile
and web.

The main shell reserves the navigation dock's measured height, including safe
areas and text scaling, so the document upload action stays above the dock.

Validation: `flutter test test/background_upload_test.dart` covers automatic
recovery, polling, stale leases, bounded retries, navigation, account changes,
categories, and the upload button's position at 390 px with normal and enlarged
text. These checks use mocked providers; they do not prove live AI uptime or
OS background execution.
