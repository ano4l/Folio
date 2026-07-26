# Backend plan

## Architecture

Spring Boot is the system-of-record API. PostgreSQL stores users, document metadata, extracted fields, deadlines, questions, citations, consent, and audit events. S3 stores encrypted source files. An asynchronous worker handles OCR, classification, extraction, embeddings, and summarisation.

## Initial API surface

- `GET /api/health` — service health check.
- `GET /api/documents` — authorised document metadata.
- `POST /api/documents` — accept upload completion metadata; source bytes go to S3.
- `GET /api/documents/{id}` — summary, entities, processing state, and authorised preview URL.
- `POST /api/questions` — retrieve authorised chunks and return answer plus citations.
- `GET /api/deadlines` — extracted actions ordered by urgency.
- `GET /api/audit-events` — current user’s access history.

## Security invariants

- Authorise every document and chunk by authenticated user/tenant before retrieval.
- Use OIDC subject IDs, not email addresses, as identity keys.
- Encrypt S3 and PostgreSQL backups, use TLS, and issue short-lived signed URLs.
- Keep prompt and response audit metadata, never raw document contents in application logs.
- Present AI output as assistance, not authoritative financial advice, and always return citations.

## Delivery sequence

1. Add OIDC resource server and user provisioning.
2. Add PostgreSQL migrations and document metadata entities.
3. Add S3 signed upload/download flow.
4. Add queue-backed processing state machine.
5. Add OCR/extraction worker and vector index.
6. Add retrieval-grounded Q&A with citation validation.
7. Add audit events, retention jobs, rate limits, and observability.
