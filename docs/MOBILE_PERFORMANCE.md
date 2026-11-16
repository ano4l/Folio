# Mobile performance changes — 2026-10-12

## Implemented

- Mount each main tab on its first visit using a non-swipeable `PageView` with
  keep-alive pages. Retain visited page state without laying out every inactive
  page through `Offstage`. Disable animation/focus on hidden pages. Tab switches
  do not composite a full-page opacity animation; the shell reuses page widgets.
- Subscribe dashboard, documents, deadlines, security and study screens to
  their relevant data instead of every global notification. Capture mutable
  deadline completion and quiz answers as scalar values so changes remain visible.
- Build vault document cards, deadline rows, activity log rows and document chat
  picker rows lazily with `ListView.builder`.
- Replace live backdrop blur in document badges and the floating navigation
  dock with solid surfaces. Keep their colours and rounded shapes, isolate the
  dock's paint, cache the theme, and skip scale-animation widgets on static cards.
- Avoid repainting the activity gauge when its numeric values are unchanged.
- Debounce document searches by 180 ms and reuse normalized search text for
  immutable document instances. Empty searches skip full-text normalization.
  The weak cache allows discarded documents to be collected.
- Copy queued workspace snapshots without a JSON round trip. Encode and decode
  persisted JSON in a background isolate on mobile; retain encrypted storage,
  account ownership and ordered writes.
- Buffer streamed AI text and publish message objects at the existing 70 ms
  update interval, flushing pending text on completion or interruption. Unrelated
  screens and the chat hub no longer rebuild for each partial answer.
- Remove the document detail `IndexedStack` that laid out the full extracted
  text even while its summary was visible. Mount only the selected detail tab.
  Extracted text uses lazy sections capped at 2400 UTF-16 code units, split at
  whitespace and preserving the original characters and surrogate pairs.
- Bound reader paragraph layout using the same display sections. Preserve only
  actual extraction page numbers; sections are not invented source pages.
  Debounce reader search and normalize pages only when searched. Search scans
  original pages so matches crossing display sections remain discoverable.
- Decode successful API response JSON once. Parse responses over 32 KB in a
  background isolate, with the session-generation guard checked afterward.
- Modernize the iPhone dock with a luminous glass-style gradient, a white
  selected capsule, 58-point minimum targets and one 120 ms state animation.
  This is a Flutter approximation with an opaque backing, not native Liquid
  Glass. It avoids live backdrop sampling during scrolling. High Contrast uses
  a solid white surface and stronger border; Reduce Motion removes animation.
  Study spaces are reachable directly from the header on every main tab.
- Coalesce workspace save bursts within 250 ms into one immutable snapshot and
  encrypted write. The timer is bounded rather than restarted continuously.
  Flush pending saves and draft changes before account reset, disposal or app
  backgrounding, preserving owner capture and ordered writes.
- Main-tab subscriptions return a constant empty selection while inactive,
  avoiding document/log/quiz snapshot allocations for unrelated notifications.
  Separate pushed document conversations continue receiving stream updates.
- Render the dashboard gauge immediately instead of rebuilding its text during
  a 900 ms introductory animation. Cache parsed task dates and index calendar
  events by day rather than scanning every task for each calendar cell.
- Extract document deadlines in a background isolate during cache restoration
  and refresh; see `DOCUMENT_DEADLINES.md` for date-review and source rules.
- Diagnostics also report frames exceeding 8.33 ms and aggregate workspace
  counts (documents, text-character count, tasks, imported deadlines and reviews).
  No document text, date values or account identifiers are exposed.

## Evidence and limits

The interaction-focused pass adds `ext.folio.frameTimings` in debug mode only.
It keeps at most 600 frame timings, reports build/raster median, p95 and maximum,
and counts frames exceeding 16.67 ms on either thread. It contains no document or
account data. Reset before a scrolling/navigation sample; startup frames otherwise
contaminate the results. This is diagnostic telemetry, not a release FPS benchmark.

The complete optimized iOS build compiled Dart and all native plugins successfully.
xcross signed and installed it on the connected iPhone, attached the debugger and
reported the Dart VM service and hot reload ready. The earlier debug session had
ended, so the changes were applied through a fresh install and launch.
No automated tests or before/after frame-rate benchmark were run in this pass.
These changes remove identifiable work; they do not establish a numerical speedup.

### Interaction sample before the second pass

After resetting diagnostics, the user's Home/Documents scrolling, tab switching
and document-opening sample produced 498 frames: build p50 5.449 ms, p95 10.977 ms,
maximum 526.858 ms; raster p50 0.098 ms, p95 0.247 ms, maximum 2.052 ms. Sixteen
frames exceeded 16.67 ms on either thread. The user reported only slight improvement.
This sample shows a UI-thread outlier, not proof of its exact cause. A 120 Hz
display has a shorter 8.33 ms budget than this diagnostic counter measures.

The old debug process later exited with `X09; Terminated due to memory issue`.
The hidden full-text layout is a concrete source of avoidable layout and memory
work, but the exit report alone does not attribute the termination to it.

### Second pass installation and verification

The second pass compiled its Dart kernel and native plugins, signed successfully,
installed on the same connected iPhone, and attached its debugger. Hot reload
applied the final header and reader-search changes. A focused `dart analyze` of
the six changed implementation files completed with `No issues found!`.
No automated tests were run.

Diagnostics reset successfully before requesting another interaction sample.
Subsequent timing and VM requests timed out while the xcross process remained
running. There is no usable second-pass interaction measurement or user verdict
yet, so the remaining lag must not be described as resolved.

### Further optimization and deadline integration

After the user reported remaining slowness, the additional save batching,
inactive-tab subscription guards, static gauge and calendar date index were
compiled and installed on the iPhone. One attempted hot restart lost its device
connection; after the user confirmed the phone was connected and unlocked, a
fresh final install launched and exposed its VM service successfully.

Live diagnostics confirmed 5 saved documents and 4 automatically imported
document deadlines. Timing capture was reset before another requested manual
scrolling/navigation sample. Static analysis reported no errors or warnings,
with style-level informational brace suggestions remaining. No automated tests
were run. Release performance and zero-lag interaction remain unverified.

xcross produces debug/JIT builds. Flutter recommends profile builds for performance
measurement, since debug mode includes checks and tooling overhead. A macOS
profile/release build is required before assessing production iOS performance.

- [Flutter performance guidance](https://docs.flutter.dev/perf/best-practices)
- [Flutter build modes](https://docs.flutter.dev/testing/build-modes)
- [xcross build limitations](https://github.com/arxdeus/xcross#readme)
