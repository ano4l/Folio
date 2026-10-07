# Folio Mobile — shared Android and iOS app

This Flutter app is the source of truth for both mobile platforms. The green/teal Android design, typography, screens, state, and interactions are shared with iOS through `lib/main.dart`.

The older blue/indigo SwiftUI prototype has been removed from the repository. For the current iOS app use this directory's `ios/Runner.xcworkspace` and the Runner scheme.

## Design and features

- Teal `0E7C74`, warm paper `FAF9F5`, DM Sans body and Fraunces headings.
- Shared login/MFA, adaptive phone/tablet navigation, document vault, per-document AI conversations, readable Markdown, tasks/calendar and security controls.
- Retained tabs, short transitions, visible Material press feedback and reduced-motion support.
- Account-scoped encrypted device storage for chat history, drafts, saved answers and tasks.
- Native scanning/OCR adapters return the same page-number/text contract to Flutter. Android uses ML Kit; iOS uses VisionKit, Vision and PDFKit. Native controls and recognition results need not be pixel/text identical.
- The iOS Documents screen adds on-device PDF tools: combine PDFs, make a PDF from images, extract selected pages, and export readable DOCX text into a PDF. Word page layout, charts, headers and footnotes are not retained; review the new PDF before sharing. Finished files can be shared or uploaded to the same authenticated vault and processing API as Android.
- The circular vault counter and all five product screens come from shared Flutter widgets. The retired blue SwiftUI demo is not an iOS build target.

## Development

Run commands from `mobile/` using the same Flutter SDK version on both platforms and keep `pubspec.lock`.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Android: `flutter build apk --debug`.

iOS requires a Mac with Xcode. Start with `flutter build ios --debug --no-codesign`, then open `ios/Runner.xcworkspace`, select your signing team and device, and run Runner. See [the iOS parity/build guide](../docs/IOS_FLUTTER_PARITY.md) for archive instructions and verification gates.

## Verification scope

Flutter widget tests exercise Android and iOS platform modes, shared theme values, large text, phone/tablet layouts, keyboard/safe-area insets, chat drafts and iPad share anchors. Platform-mode tests are not a substitute for native iOS compilation or device QA.

On the corresponding device, run:

```sh
flutter test integration_test/android_ocr_test.dart -d <android-device-id>
flutter test integration_test/ios_ocr_test.dart -d <ios-device-id>
```

The OCR fixture does not call AI or upload documents. iOS native compilation/camera/OCR, Face ID, VoiceOver, screenshot comparisons and frame profiling still require Mac/device verification. Read [implementation progress and limitations](../docs/ANDROID_IMPLEMENTATION_PROGRESS.md) before release; backend changes must be deployed separately.
