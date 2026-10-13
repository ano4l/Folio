# Android and iOS

Both platforms run `mobile/lib/main.dart`, the shared Dart screens, and the same theme. Native permission prompts, scanners, biometric dialogs, and share sheets use their platform's controls. OCR results can differ between engines.

## Build iOS on a Mac

Install Flutter, Xcode with its iOS SDK, and CocoaPods where required. Use the same Flutter version across development machines and keep `pubspec.lock`.

```sh
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build ios --debug --no-codesign
open ios/Runner.xcworkspace
```

Choose the Runner scheme, select your signing team and device, and run. The bundle identifier is `za.co.folio.folioMobile`; confirm it matches the intended App Store record before distributing.

After configuring signing:

```sh
flutter build ipa --release
```

Use `--dart-define=FOLIO_API_URL=https://your-host/api` to select a different backend. For attached iPhone development from Windows, see [the xcross guide](IOS_XCROSS.md).

## Native Document Operations

Android uses ML Kit for scanning and OCR. iOS uses VisionKit, Vision, and PDFKit through the `folio_documents` plugin. Both return extracted text with page metadata to the shared Flutter services.

PDF tools create separate files. Readable Word paragraphs can be converted to PDF, but original layout, charts, headers, and footnotes are not retained. Files upload only when the user saves them to the vault.

The local storage and text-to-speech dependency overrides under `mobile/third_party/` provide SwiftPM manifests for the Windows build workflow.

## Device Verification

See [testing](TESTING.md) for automated checks. Before releasing, compare matching phone and tablet screens on Android and iOS, including large text, landscape, keyboards, safe areas, and reduced motion.

Exercise camera permission denial, cancelled scans, rotated photos, selectable and scanned PDFs, oversized files, biometric unlock, sharing on iPad, dictation, and read-aloud. Check cold launch and scrolling in a profile or release build. Widget tests with an iOS platform override do not establish native compilation or device performance.
