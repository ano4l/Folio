# Folio

Student document workspace with a Next.js web app/API and one shared Flutter mobile app for Android and iOS.

## Repository layout

- `frontend/` — active web app and server API routes.
- `mobile/` — shared green Flutter app, including Android and iOS native adapters.
- `supabase/` — database migrations required by the active apps.
- `docs/` — app requirements, engineering notes, deployment and verification guides.
- `submissions/` — academic final documents, briefs, exported figures, diagram sources, planning material and generation scripts.
- Root package/configuration files — retained for existing development and deployment entry points.

## Run locally

Web app:

```sh
npm ci --prefix frontend
npm --prefix frontend run dev
```

Set local provider configuration using `.env.example`; never commit credentials.

Mobile app:

```sh
cd mobile
flutter pub get
flutter run
```

Build iOS on a Mac from `mobile/ios/Runner.xcworkspace` using Runner. Android and iOS use the same Dart screens and theme. See [iOS parity and build instructions](docs/IOS_FLUTTER_PARITY.md).

## Documentation

- [Development](docs/DEVELOPMENT.md)
- [Web deployment](docs/VERCEL_SUPABASE.md)
- [Mobile implementation and verification limits](docs/ANDROID_IMPLEMENTATION_PROGRESS.md)
- [Submission contents](submissions/README.md)

## Cleanup

The separate blue SwiftUI prototype, unused Spring Boot/AWS scaffold, copied skills, temporary output and stale Next.js builds were removed from this working folder. A recoverable copy of those files, including uncommitted changes, is in the sibling `Folio-cleanup-recovery-2026-09-27/` folder. No app secrets, Git history, active app sources or database migrations were deleted.
