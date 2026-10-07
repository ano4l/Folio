# iOS / Android: one Flutter app

## Correct build target

The green Android UI is the design source of truth. Both platforms must run `mobile/lib/main.dart`, the shared screens in `mobile/lib/screens/`, and `mobile/lib/theme/app_theme.dart`.

The former top-level `ios/FolioMobile/` was a separate legacy SwiftUI prototype, now removed from the active checkout and retained in the sibling cleanup recovery folder. Its `teal` color was actually blue (`007AFF`) and it used indigo gradients. The user's blue dashboard screenshot matches that prototype's “Welcome back, Alex” source text. Do not use its historical setup instructions for a new release.

If an iPhone still shows “Welcome back, Alex” and sample award letters, it is running that legacy demo. Remove the old installation, then install the Flutter Runner from this checkout. The Flutter app starts with real sign-in and loads account data through the Vercel API; it has no bundled sample documents.

## Build on a Mac

Install Flutter, Xcode and its iOS SDK, and CocoaPods for plugins requiring it. This pass used Flutter 3.41.4 / Dart 3.11.1 on Windows. Use the same Flutter version as the Android checkout (`flutter --version`), and keep `pubspec.lock`.

From the repository root:

```sh
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build ios --debug --no-codesign
open ios/Runner.xcworkspace
```

In Xcode choose **Runner**, select your Apple signing team and an iPhone/iPad, then Run. Do not create a new SwiftUI project. Verify the bundle identifier against the existing App Store record before distributing: this checkout uses `za.co.folio.folioMobile`; do not invent a replacement if an existing app uses another identifier.

For a signed archive, after signing is configured:

```sh
flutter build ipa --release
```

The build uses the shared API default; for another backend pass the same `--dart-define=FOLIO_API_URL=...` used on Android. Native compilation, signing, and installation cannot be verified on this Windows host.

## Shared UI contract

- Green/teal `0E7C74`, warm paper `FAF9F5`, DM Sans body, Fraunces headings.
- Same login/MFA, home, documents, per-document chats, formatted AI output, tasks/calendar, security screens and state.
- Same app-bar alignment, typography metrics, touch sizes, ink feedback, reduced-motion behavior and retained-tab transitions. iOS remains the real target platform for editing, accessibility and back gestures; it is not globally spoofed as Android.
- Shared scroll configuration explicitly uses Android overscroll treatment and clamping physics. Individual screens with explicit physics retain the same override on both platforms. Home refresh uses the same Material indicator instead of adapting to an iOS spinner.
- Responsive layout uses the same breakpoints. Device safe areas and keyboards may change available space, not the design.
- Native permission prompts, scanner, biometric prompts, and share sheet necessarily use their platform's UI. OCR engines may produce different text; exact OCR output parity is not promised.
- iOS uses a restrained translucent bottom navigation dock over the shared content; Android keeps its existing opaque dock. High-contrast iOS appearance uses an opaque dock.

## Native adapters added in this pass

- iOS `folio/documents` channel: VisionKit camera scan to PDF; Vision OCR for images and scanned PDF pages; PDFKit selectable text preservation; EXIF-aware image downsampling; serial background reading; 20-page / 20-MB limits; cancellation and recoverable errors.
- iOS camera purpose string. Camera denial and unsupported devices retain file import as a fallback. VisionKit checks the page limit after capture (unlike Android's scanner capture limit).
- Anchored sharing for iPad with recoverable error feedback, shared by documents and AI answers.
- iOS PDFKit adapters for PDF merge, page extraction and image-to-PDF. Shared Flutter code exports readable DOCX text to a PDF using a bundled font. These tools create temporary local PDFs and upload only when the user chooses to save to the vault. DOCX page layout, charts, headers and footnotes are not retained; review the new PDF before sharing.

## Verification and remaining gates

Verified on Windows in this pass: all 28 Flutter tests passed, including eight new parity tests covering Android/iOS theme equality, green login, phone/tablet navigation and chat with enlarged text/insets, and share-sheet origin arguments. No native iOS build or pixel comparison is claimed.

Flutter tests can exercise iOS platform mode on Windows. They cannot prove native compilation, camera capture, PDFKit/Word conversion, Keychain, Face ID, VoiceOver, or iOS rendering/frame performance.

Before release on a Mac/device:

1. Build the Flutter Runner, not the legacy prototype. Verify green login and shared app navigation.
2. Compare matching phone/tablet screenshots with Android, including large text, notch/home indicator, landscape, keyboard, and reduced motion.
3. Run document chats, draft restoration, source sheets, task undo, and iPad sharing.
4. Test camera permission allowed/denied, cancel, unsupported-device fallback, 1/20/21-page scans, rotated photos, selectable/scanned/locked PDFs, empty pages and oversized files.
5. Verify cold launch, Keychain persistence, Face ID lock, background privacy, dictation/read-aloud, and VoiceOver. iOS does not have Android's FLAG_SECURE screenshot-prevention equivalent in this implementation.
6. Check actual icon/launch-screen artwork, signing, release frame timing, and backend contract deployment. Full dark mode is still pending on both platforms.

Reference: [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels), [Apple document camera](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller).
