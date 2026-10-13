# Development

Folio has a Next.js web app/API in `frontend/` and a Flutter app in `mobile/`. Both clients use the same API. Keep package lockfiles, native mobile projects, and database migrations in version control.

## Web

Copy `.env.example` to `frontend/.env.local` and configure the providers described in the [deployment guide](VERCEL_SUPABASE.md).

```sh
npm ci --prefix frontend
npm run dev
npm run build
```

The root npm commands delegate to `frontend/`. Run the Next.js app from that directory when using its CLI directly.

## Mobile

```sh
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

Use `flutter build apk --debug` for an Android debug build. For iOS, see the [Mac build guide](IOS_FLUTTER_PARITY.md) or [Windows device workflow](IOS_XCROSS.md).

`mobile/plugins/folio_documents/` implements native iOS document operations. The packages in `mobile/third_party/` are local dependency overrides needed for iOS SwiftPM builds; retain their sources and licenses.

## Local Files

`submissions/`, `output/`, `outputs/`, `tmp/`, `temp/`, `mobile/releases/`, and `.private/` are ignored. Store one-off scripts under `scripts/`; only the documented iPhone helper is tracked. Put personal research and previous implementation notes in `.private/notes/`.

See [testing](TESTING.md) for checks to run before a release.
