# Testing

## Web

Run from `frontend/` with a Node.js version that supports native TypeScript stripping:

```sh
npx tsc --noEmit
node --experimental-strip-types --test lib/server/document-pages.test.ts lib/server/openrouter.test.ts
npm run build
```

The tests cover page metadata and provider retry/error handling. A successful build does not verify live email delivery, storage access, or model answer quality.

## Mobile

Run from `mobile/`:

```sh
flutter analyze
flutter test
```

Native OCR tests use synthetic documents and require the corresponding device:

```sh
flutter test integration_test/android_ocr_test.dart -d <android-device-id>
flutter test integration_test/ios_ocr_test.dart -d <ios-device-id>
```

Platform overrides in widget tests do not compile the native iOS app.

## Release Checks

- Sign up, verify email, sign out, and sign in with MFA.
- Confirm a second account cannot access the first account's documents.
- Upload a synthetic PDF, inspect extracted pages, and check answer citations against the source.
- Test failed processing, retry, unreadable pages, document deletion, and restoration.
- Exercise scan/import, PDF tools, biometrics, dictation, read-aloud, and sharing on both platforms.
- Check small phones, tablets, large text, keyboard insets, and reduced motion.
- Measure scrolling and navigation in a profile or release build on a real device.

Record the build and device used for each result. Debug compilation and widget tests do not establish store signing, native behavior, or live provider reliability.
