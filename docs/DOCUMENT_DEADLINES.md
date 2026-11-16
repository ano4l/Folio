# Document deadlines in the mobile calendar

Previously, extracted document entities were displayed in document details, but
`refreshDocuments()` and cache restoration never converted their dates into
`AppState.deadlines`. The Deadlines tab and calendar therefore only showed tasks
the user entered manually.

## Implemented

- Scan cached and refreshed document text/pages and deadline-labelled entities
  in a background isolate. No new AI call or server deployment is required.
- Import explicit deadlines with full, valid dates. Recognize ISO dates, English
  month names, ordinals, and numeric dates whose day/month order is unambiguous.
- Verify entity dates also occur in source text before automatic import. Keep
  ambiguous dates, missing years and uncertain/example dates in a review queue.
  Review requires choosing a date; no year or locale order is silently guessed.
- Keep source document, excerpt and actual extraction page number when available.
  The same task collection feeds the list, calendar markers, dashboard and ICS export.
- Deduplicate by source document, event category and date. Retain completion,
  snoozes and edits across refreshes; persist dismissed imported deadline keys
  so a deleted task does not reappear. Deleting and undoing restores that key.
- Store deadlines and dismissal state in the existing encrypted, account-specific
  device workspace. This does not add cross-device task synchronization.
- Calendar markers use a precomputed date index; parsed task dates are cached.

## Limits

This is conservative date recognition, not semantic extraction of every possible
schedule. Relative dates (for example, "two weeks after acceptance"), unsupported
date formats, unreadable text and dates with no deadline cue are not automatically
scheduled. Separate events with the same category and date in one document share
one imported reminder; its source excerpt remains available for checking.

No automated tests were run in this pass. Device import counts and user interaction
feedback must be recorded separately from compilation or static analysis.

## Device checkpoint — 2026-10-12

The final iPhone build compiled, signed, installed and attached its debugger.
Live aggregate diagnostics reported 5 saved documents, 36,924 extracted-text
characters, 4 tasks, 4 imported document deadlines and 0 date-review candidates.
This verifies the import ran against the user's saved workspace. It does not
verify every possible date or replace checking each date against its source.
The user was asked to check the list and calendar in the running app.
