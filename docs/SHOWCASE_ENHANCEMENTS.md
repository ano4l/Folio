# Study and Document Workflows

The shared Flutter app and Next.js API support the workflows below. The web workspace supports the same core Study journey; see [Web App](FRONTEND.md) for browser-specific behaviour.

## What is available

| Area | Enhancements |
| --- | --- |
| Study | Course spaces; rename/delete courses; select/remove vault sources; upload course material with an exact document ID association; staged upload feedback; pull to refresh; sample lecture upload |
| AI quizzes | Real four-option questions in chat; 3/5/8 requested questions; foundation/understanding/application difficulty; optional topic; immediate explanations and source passages; scores; missed-question practice; quiz-to-card conversion |
| Revision | Cards from saved notes and completed quizzes; reveal before self-rating; repeat after 10 minutes, or tomorrow with doubling intervals capped at 30 days; progress and accuracy per course; completed-session summary |
| Notes | Create/edit/search/delete with undo; source and page links; capture selected passages; save grounded chat explanations; PDF and Markdown export including revision cards |
| Reading | Search extracted text and highlight matches; page selection using supplied extraction metadata; font controls; passage-to-chat draft; original-file access; extracted text or readable-text PDF export |
| PDF tools | Camera scanning; merge with explicit file ordering; extract/reorder/remove pages; rotate; JPG/PNG to PDF with ordering; Word text to PDF; pasted text to PDF; share or upload output |
| Vault | Favourites; category filtering; full-text search; sorting by recent/title/page count; title/category editing; existing deletion and restoration flows |
| Planning | Standalone or document-linked tasks; edit date/title/source/priority; high-priority filter; search; postpone by one day; delete with undo; completed task editing; ICS calendar export; exam revision-plan preview |
| Chat | Quiz-aware copy/share/read-aloud; conversation Markdown export with source passages; saved-answer filtering; reading a citation in context; quiz request retry |
| Activity | Persist the last 300 device events per account; category and text filters; CSV export with formula-safe cells |

## A short showcase walkthrough

1. Sign in, open **Home → Study**, and create a course.
2. Upload your lecture notes, or choose **Try sample lecture material** in an empty course. This uploads a self-authored database lesson through the real processing pipeline.
3. When the source says **Ready**, open **Read**. Search for “transaction”, select a passage, and save it as a note.
4. Open **Study** for that source. Explain simply or teach step by step; save a sourced answer as a study note.
5. Choose **Quiz me**, select length/difficulty/topic, and answer the actual options. Open a source explanation; practise missed questions; save revision cards.
6. Open **Revision**, reveal a card, and rate your recall. Show the course's saved progress and export its notes as PDF.
7. Choose **Plan revision for an exam**, review the proposed dates, and save them. In **Deadlines**, edit a task and export calendar events.
8. In **Documents → Document tools**, combine files in an explicit order or extract selected pages; share the new copy. Favourite a source and change its title/category.

## Data and capability boundaries

- Study spaces, notes, cards, favourites, tasks, chats and device activity use the existing account-specific secure device store. They are not cloud-synchronised. Exports are user-initiated copies outside that store.
- Course progress counts saved quiz answers, including repeated practice and sources shared by multiple courses. Clearing a document chat removes those quiz results from its progress. Self-rated cards are revision scheduling, not a mastery or grade prediction.
- Quizzes sample readable passages, use source quote validation, and can return fewer questions when the model produces insufficient valid evidence. Source quote validation does not independently prove the answer key is semantically correct. Check the original for important details.
- The reader displays extracted text. It does not reproduce the original PDF layout or draw annotations into the original file. Saved passages are linked notes.
- PDF tools create a separate file. Inputs and outputs use a 20 MB limit; Android PDF input and combined output support up to 100 pages. Images support up to 20 files. Word conversion exports readable paragraphs and can change formatting. Original files are preserved.
- Calendar exports create all-day events. The user's calendar app controls import and reminders. Folio itself does not send deadline notifications.
- Native iOS changes require a Mac build and device review. Android compilation confirms native API compatibility, not physical-device behaviour.
- Deployment must include `/api/v1/ai/quiz`, the document `update` action, and page metadata returned by `/api/v1/documents`. The Android build retains the existing production API URL unless `FOLIO_API_URL` is supplied at build time.
- AI requires OpenRouter and Supabase server configuration. Quiz generation uses a compatible free-model fallback when its primary endpoint is unavailable, while keeping source validation and privacy routing.

## Implementation references

Android PDF operations use [PDFBox-Android](https://github.com/TomRoush/PdfBox-Android). Photo orientation uses [AndroidX ExifInterface](https://developer.android.com/jetpack/androidx/releases/exifinterface). Owner-scoped document updates follow [Supabase's update API](https://supabase.com/docs/reference/javascript/update). No database migration is required for this slice.

## Verification

On 13 October 2026, Flutter analysis and all 47 mobile tests passed. The Next.js production build and 35 server/workspace tests passed. Live production quizzes returned 3, 5 and 8 questions with validated answer indexes and source excerpts. Owner isolation and invalid-request checks passed.

An Android emulator capture run completed the signed-in vault, reader, Study, five-question quiz, scoring and task screens. Browser verification covered uploads, saved notes/cards, missed-question practice, source navigation, local persistence and exports. These checks do not establish physical iPhone behaviour, store signing or email-delivery reliability. Generated screenshots and the user manual remain local deliverables excluded from Git.
