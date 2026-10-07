# Folio development guide

## Active applications

`frontend/` contains the Next.js web app and API. `mobile/` contains the shared Flutter app for Android and iOS. The active API does not require the former Spring Boot scaffold.

Keep `supabase/migrations/`, package lockfiles, native mobile projects, local environment configuration and deployment files. Historical submission material is under `submissions/`, not in app source folders.

## Web

Use a Node.js version supported by the installed Next.js version and the deployment environment. Install from the frontend lockfile:

```sh
npm ci --prefix frontend
npm --prefix frontend run dev
npm --prefix frontend run build
```

Use `.env.example` for provider variable names; keep values in ignored local environment files. See [deployment guidance](VERCEL_SUPABASE.md). Root npm scripts still delegate to the frontend. The cleanup did not change Vercel project settings or deploy either app.

## Mobile

From `mobile/`:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Android debug build: `flutter build apk --debug`.

For iOS, use a Mac and the existing Runner workspace. Do not create a separate SwiftUI app. See [iOS parity](IOS_FLUTTER_PARITY.md) and the [mobile README](../mobile/README.md).

## Submissions

Final documents and figure exports are in `submissions/final/`. Assignment briefs, diagram sources and build scripts have separate subfolders. Do not regenerate over submitted files; script output goes to `submissions/generated/`.

## Verification

Static checks and widget tests do not establish live provider, deployment or native-device behavior. Retain the verification limits in [mobile implementation progress](ANDROID_IMPLEMENTATION_PROGRESS.md).
