# Folio

A student document workspace for funding paperwork and course materials. Folio combines a private vault, document extraction, source-linked AI answers, study notes, quizzes, and deadline tracking.

## Structure

| Directory | Contents |
| --- | --- |
| `frontend/` | Next.js web app and API |
| `mobile/` | Flutter app for Android and iOS |
| `supabase/migrations/` | Database migrations |
| `docs/` | Development, deployment, and platform guides |
| `scripts/ios-xcross.ps1` | Windows iPhone development helper |

## Development

Use Node.js 20.9 or newer. Copy `.env.example` to `frontend/.env.local` and fill in the provider values.

```sh
npm ci --prefix frontend
npm run dev
```

For mobile, install Flutter and run:

```sh
cd mobile
flutter pub get
flutter run
```

The mobile API URL can be set with `--dart-define=FOLIO_API_URL=https://your-host/api`. See the [development guide](docs/DEVELOPMENT.md) and [mobile README](mobile/README.md) for build commands.

## Documentation

- [Product requirements](docs/PRD.md)
- [Web implementation](docs/FRONTEND.md)
- [Deployment](docs/VERCEL_SUPABASE.md)
- [Testing](docs/TESTING.md)
- [Android and iOS](docs/IOS_FLUTTER_PARITY.md)
- [iPhone development on Windows](docs/IOS_XCROSS.md)

Academic submissions, generated outputs, temporary files, releases, and local research notes are ignored by Git. Keep credentials in local environment files. The iPhone helper is the only tracked script under `scripts/`.
