# Folio Mobile

One Flutter app for Android and iOS. Screens, theme, navigation, and account state live in `lib/`; native adapters provide scanning, OCR, PDF operations, and platform integrations.

The app includes document upload and reading, document-scoped chat, study notes and quizzes, revision cards, tasks, and calendar export. Chats, courses, notes, tasks, and activity are stored in an encrypted account-specific device workspace. They do not sync between devices.

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

To use a different API:

```sh
flutter run --dart-define=FOLIO_API_URL=https://your-host/api
```

Keep `pubspec.lock` and the local packages under `plugins/` and `third_party/`. The dependency overrides add iOS SwiftPM packaging to the storage and text-to-speech packages.

## Builds

Android:

```sh
flutter build apk --debug
```

iOS on a Mac:

```sh
flutter build ios --debug --no-codesign
open ios/Runner.xcworkspace
```

Select the Runner scheme and configure signing in Xcode. See [platform setup](../docs/IOS_FLUTTER_PARITY.md) and the [Windows iPhone workflow](../docs/IOS_XCROSS.md).

## Checks

Widget tests cover shared UI and state. Scanning, OCR, biometrics, sharing, and frame performance also need native-device testing. See [testing](../docs/TESTING.md) for commands and release checks.

PDF tools produce separate files. Word conversion retains readable paragraphs, not the original layout. Upload jobs continue during in-app navigation but can be interrupted when the operating system suspends or closes Folio.
