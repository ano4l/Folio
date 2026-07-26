# Folio development guide

## 1. Repository layout

- `app/` — Next.js App Router entry points and global styling.
- `frontend/` — deployable Next.js workspace and its package manifest.
- `frontend/src/components/FolioApp.tsx` — current prototype shell, screens, state, and interactions.
- `frontend/app/globals.css` — design tokens, component styles, responsive breakpoints, and mobile navigation.
- `backend/` — Spring Boot API scaffold, controllers, configuration, and Dockerfile.
- `docs/` — product requirements, architecture, delivery plans, hosting decisions, and progress tracking.
- `folio-student-finance-prototype.jsx` — original UI reference supplied for the build.
- `docker-compose.yml` — local service orchestration, including PostgreSQL when configured.
- `.env.example` — names and descriptions of required environment variables; never put secrets here.

## 2. Prerequisites

- Node.js 20 or the version pinned by the deployment platform.
- npm compatible with the Node.js version.
- Java 21 and Maven, or the Maven wrapper when added.
- Docker Desktop and Docker Compose for local infrastructure.
- Git configured with the repository remote.
- Optional provider credentials for OIDC, object storage, OCR, vector search, and model services. Do not use production credentials locally.

## 3. First-time setup

### Frontend-only prototype

```powershell
npm install
npm run dev
```

The root scripts delegate to the `frontend/` workspace. The development server runs the mocked application and does not require a database or external AI provider.

### Backend

```powershell
cd backend
mvn spring-boot:run
```

Keep backend configuration in environment variables or a local ignored profile. The scaffold health endpoint should be checked before connecting the frontend.

### Local infrastructure

```powershell
docker compose up -d
```

Use local-only database and object-storage credentials. Stop services after work with `docker compose down`; do not delete volumes unless the local data is disposable.

## 4. Common commands

- `npm run dev` — start the frontend development server.
- `npm run build` — build the frontend through the root workspace script.
- `npm run start` — serve the production frontend build locally.
- `npm --prefix frontend run lint` — run frontend linting when configured.
- `mvn test` from `backend/` — run backend tests.
- `mvn spring-boot:run` from `backend/` — start the API locally.
- `docker compose config` — validate Compose configuration.
- `git diff --check` — detect whitespace errors before committing.

## 5. Environment and secrets

- Copy `.env.example` to an ignored local environment file only when needed.
- Never commit `.env`, private keys, OIDC client secrets, database passwords, storage secrets, bearer tokens, or real student documents.
- Keep browser-exposed variables limited to values that are safe to publish, such as a public API origin.
- Use separate credentials and buckets for local, preview, pilot, and production environments.
- Rotate any secret that is accidentally printed, committed, or shared in a screenshot.

## 6. Feature delivery workflow

1. Read the relevant PRD, frontend, backend, and progress sections before changing code.
2. Identify the user journey, API contract, state transitions, permission rules, and audit events.
3. Add or update types and tests before replacing mocked state.
4. Implement loading, empty, error, retry, forbidden, and processing states.
5. Validate keyboard use, mobile layout, source citation behavior, and sensitive-data handling.
6. Run the smallest relevant tests, then a full build and security review.
7. Update `docs/progress.md` with status, evidence, risks, and next actions.
8. Commit a focused change with a descriptive message.

## 7. Code standards

- Use TypeScript strictness and avoid `any` for API data.
- Keep components focused; split `FolioApp.tsx` when a feature gains network state or independent tests.
- Keep imports at the top and preserve existing comments unless documentation changes are requested.
- Prefer explicit names for processing states, permission scopes, and error codes.
- Make source provenance part of the data type, not an optional presentation detail.
- Keep server-authoritative data separate from ephemeral UI state.
- Use database migrations rather than editing deployed schemas manually.
- Validate all external input at the API boundary and again at security-sensitive operations.

## 8. Testing expectations

Every feature should have the lowest useful level of coverage:

- Unit tests for pure parsing, validation, formatting, and authorisation helpers.
- Integration tests for persistence, API responses, signed URLs, and state transitions.
- Worker tests for retries, idempotency, parser versions, and safe failures.
- End-to-end tests for user-critical journeys.
- Accessibility checks for forms, dialogs, navigation, status updates, focus, and contrast.
- Security tests for IDOR, cross-user retrieval, consent expiry, malicious files, and log redaction.

## 9. Troubleshooting

- **Frontend dependency failure:** run `npm install` from the repository root, then verify `frontend/package.json` and the root workspace scripts.
- **Backend cannot start:** check Java/Maven versions, database availability, and required environment variables.
- **CORS errors:** confirm the frontend origin is listed in backend configuration and that the API URL is not using a server-only variable in browser code.
- **Document stuck in processing:** inspect the document state, worker lease, retry count, and safe failure category; do not manually mark it ready.
- **Missing Q&A citation:** treat it as a failed contract or abstention bug; never hide the missing evidence in the UI.
- **Deployment mismatch:** reproduce the platform install and build commands locally from the repository root.

## 10. Quality bar

- Preserve the Folio visual language: ink/navy, warm paper background, teal actions, amber urgency, Fraunces headings, and compact data-dense cards.
- Every AI answer must show a source document and passage/page reference or an explicit abstention.
- Treat uploaded financial documents as sensitive personal information. Do not log file contents or model prompts.
- Add tests for new API contracts and user-critical flows before replacing prototype state with network calls.

## 11. Definition of done

A feature is ready when its UI state is implemented, loading/error/empty/forbidden states are present, API contracts and migrations are documented, security and privacy implications are reviewed, audit behavior is defined, responsive/accessibility checks are complete, and the relevant build/test commands pass.

