# Railway hosting plan

## Services

Create three Railway services from this repository:

1. **folio-web** — root directory `/`, build with `npm install && npm run build`, start with `npm start`.
2. **folio-api** — root directory `/backend`, build from `backend/Dockerfile`; expose port `8080`.
3. **folio-db** — Railway PostgreSQL plugin.

## Environment variables

### Web

- `NEXT_PUBLIC_API_URL` — public API URL.

### API

- `DATABASE_URL` — Railway PostgreSQL JDBC URL.
- `DB_USERNAME` and `DB_PASSWORD` — database credentials when not embedded in the URL.
- `OIDC_ISSUER_URI`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` — Eduvos identity provider settings.
- `S3_ENDPOINT`, `S3_BUCKET`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` — object storage settings.
- `CORS_ALLOWED_ORIGINS` — deployed web origin.

## Deployment checklist

- Add health checks at `/api/health` and configure the API service health path.
- Use private networking for API-to-database traffic where available.
- Set production secrets in Railway variables, not repository files.
- Configure custom domains and HTTPS before handling real documents.
- Enable database backups and set a retention policy.
- Review logs to ensure file contents, tokens, and AI prompts are not emitted.
- Keep worker processing separate from the request service once OCR/AI processing is enabled.

## Preview vs production

The current frontend is safe for preview with mocked data. Do not upload real student documents until OIDC, signed object-storage URLs, access controls, retention, and POPIA review are complete.
