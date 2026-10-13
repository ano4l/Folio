# Web App

The web app uses Next.js App Router, React, and TypeScript. `app/page.tsx` mounts `src/components/FolioApp.tsx`, which owns the client screens and navigation. Shared styles are in `app/globals.css`.

## API

Route handlers under `app/api/v1/` handle authentication, passkeys, documents, and AI requests. Server helpers in `lib/server/` manage sessions, provider calls, extraction, and evidence formatting.

Browser mutations send `X-Requested-With: FolioWeb`. Requests use the Folio session cookie; server routes check document ownership before reading or changing records. Provider credentials and the database service-role key stay on the server.

Uploads go directly to private storage using a signed upload URL. The API then extracts readable content and generates a summary. Questions use stored document text and return source references. Processing failures and unreadable pages need explicit review.

## Client State

The web client loads documents from the API. Some interface state, including task and activity views, remains local to the current session. Check the relevant handler before treating a control as a persisted server operation.

The mobile client shares the API but has its own encrypted device workspace and additional study features. Web and mobile feature availability can differ.

See [development](DEVELOPMENT.md), [deployment](VERCEL_SUPABASE.md), and [testing](TESTING.md).

