# Railway hosting and operations plan

## 1. Deployment topology

Railway hosts the API and supporting runtime services. Vercel remains the preferred host for the Next.js web application unless a single-provider deployment is intentionally chosen. The web application must communicate with the API through HTTPS and must never connect directly to PostgreSQL or private queues.

## 2. Services

Create and name services consistently:

1. **folio-web** — Next.js workspace. If hosted on Railway, use repository root `/`, build with `npm install && npm run build`, and start with `npm start`. The root scripts delegate to `frontend/`.
2. **folio-api** — Spring Boot API from `/backend`, built from `backend/Dockerfile`, listening on the platform-provided `PORT` with `8080` as the local default.
3. **folio-db** — Railway PostgreSQL plugin with private networking enabled.
4. **folio-worker** — separate worker process once OCR, classification, embeddings, and model calls are enabled; it shares code and configuration with the API but has a distinct runtime role.
5. **folio-queue** — managed queue or supported queue provider for processing jobs and retry scheduling.

Keep the worker separate from the request service so long OCR or model operations cannot exhaust API threads.

## 3. Environment variables

### Web

- `NEXT_PUBLIC_API_URL` — public HTTPS API URL; safe to expose in browser bundles.
- `NEXT_PUBLIC_ENVIRONMENT` — preview/pilot/production label if needed for visible diagnostics.

### API and worker

- `DATABASE_URL` — Railway PostgreSQL JDBC URL.
- `DB_USERNAME` and `DB_PASSWORD` — database credentials when not embedded in the URL.
- `OIDC_ISSUER_URI`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` — Eduvos identity provider settings.
- `OIDC_AUDIENCE` — expected API audience.
- `S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` — object storage settings.
- `S3_SIGNED_URL_TTL_SECONDS` — short URL lifetime, subject to security review.
- `QUEUE_URL`, `QUEUE_ACCESS_KEY`, `QUEUE_SECRET_KEY` — processing queue settings.
- `CORS_ALLOWED_ORIGINS` — exact deployed web origins, never a wildcard in production.
- `PROCESSING_MAX_ATTEMPTS` — retry limit for worker jobs.
- `LOG_REDACTION_MODE` — enforced sensitive-field redaction configuration.
- `SENTRY_DSN` or equivalent — optional error reporting endpoint after payload review.

Do not store production secrets in the repository, Docker image, build logs, frontend variables, or documentation examples.

## 4. Environment separation

Maintain separate Railway projects or environments for local, preview, pilot, and production. Use separate databases, buckets, OIDC clients, queue namespaces, and encryption keys. Preview must not be able to read production objects even if a URL or identifier is guessed.

## 5. Deployment order

1. Provision PostgreSQL and private networking.
2. Apply database migrations using a controlled release job.
3. Deploy API and verify readiness.
4. Deploy worker and verify queue consumption with a test-safe job.
5. Configure object storage, signed URL policy, and retention rules.
6. Deploy web application with the API origin.
7. Run smoke tests for health, authentication boundary, document listing, and a synthetic processing flow.
8. Enable real-data access only after security, privacy, and rollback checks pass.

## 6. Health checks and observability

- Expose `/api/health` for liveness and `/api/health/readiness` for database, queue, and required provider readiness.
- Configure Railway health paths, startup timeout, restart policy, and resource limits.
- Emit request IDs across API and worker logs.
- Monitor API latency, 4xx/5xx rates, queue depth, processing duration, retry count, database connections, storage usage, signed URL failures, and model cost.
- Redact documents, tokens, credentials, prompts, and response bodies from logs and error reporting.
- Alert on repeated worker failures, queue growth, database saturation, failed backups, suspicious access, and readiness loss.

## 7. Security and privacy checklist

- Use HTTPS and private API-to-database/queue connections.
- Restrict service accounts to the minimum bucket, database, queue, and migration permissions.
- Rotate OIDC, storage, database, and queue credentials on a documented schedule.
- Configure object encryption, bucket blocking, lifecycle retention, versioning, and no-public-access policy.
- Set database backup retention and test restoration, not just backup creation.
- Use exact CORS origins and strict security headers on the web application.
- Review data flows under POPIA before pilot data is accepted.
- Keep real documents out of preview environments and developer machines unless explicitly approved and encrypted.

## 8. Preview versus production

The current frontend is safe for preview with mocked data. Do not upload real student documents until OIDC, signed object-storage URLs, access controls, retention, deletion, audit, logging redaction, and POPIA review are complete.

Preview environments should use synthetic documents and a mocked identity provider. Production should be gated behind a small pilot cohort and explicit incident/support ownership.

## 9. Rollback and incident response

- Keep the previous API, worker, web build, and migration versions identifiable.
- Do not roll back application code across an incompatible database migration; use expand/migrate/contract patterns.
- Pause workers before replaying or draining a poisoned queue.
- Revoke signed URL or storage credentials if object access is suspected.
- Disable affected processing providers while retaining uploaded source objects and metadata state.
- Record incident timeline, scope, affected users, containment, recovery, and required POPIA notifications.

