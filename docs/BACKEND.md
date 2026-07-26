# Folio backend implementation plan

## 1. Backend responsibilities

Spring Boot is the system-of-record API. It authenticates requests, authorises every resource, stores metadata and derived results, issues short-lived object-storage URLs, creates processing jobs, serves grounded answers, and records privacy-relevant events.

The backend must not proxy large source files through normal API requests unless a specific security workflow requires it. Source bytes belong in encrypted object storage; PostgreSQL stores references, state, structured extraction, and audit metadata.

## 2. Service boundaries

### API service

The Spring Boot API handles OIDC JWT validation, user provisioning, document metadata, signed URL creation, question orchestration, deadlines, consent, audit queries, and health endpoints.

### Processing service

A queue-backed worker handles malware scanning, OCR, layout extraction, classification, entity extraction, summarisation, chunking, embeddings, deadline candidate detection, and indexing. It must be idempotent and version every derived output.

### Storage services

- PostgreSQL stores relational metadata, user ownership, processing state, extracted entities, citations, deadlines, consent, feedback, and audit events.
- S3-compatible object storage stores encrypted originals and optionally derived page images or OCR artefacts with separate retention rules.
- A vector index stores embeddings linked to document/chunk IDs and ownership scope; it must not be queried without an authorisation filter.

### Supporting infrastructure

Use a queue for asynchronous processing, a scheduler for retries/retention/reminders, and a metrics/logging pipeline that excludes sensitive content.

## 3. Domain model

Minimum entities and important fields:

- **User:** internal ID, OIDC subject, institution, display name, status, created time, last login.
- **Role:** user ID, role name, institution/tenant scope, grant/revoke timestamps.
- **Document:** ID, owner ID, title, category, original filename, media type, size, checksum, object key, status, parser version, created time, retention expiry.
- **DocumentVersion:** document ID, source object key, processing attempt, pipeline version, status, error category, timestamps.
- **ExtractedEntity:** document version ID, field name, normalised value, display value, confidence, page, character offsets, bounding box, source text hash.
- **DocumentChunk:** document version ID, page, offsets, chunk text reference, embedding ID, retrieval visibility.
- **Deadline:** owner ID, source entity/chunk, action, due date/timezone, confidence, status, user override, completion time.
- **Question:** owner ID, question metadata, answer status, model/pipeline version, confidence, created time.
- **Citation:** question ID, document/chunk/page reference, evidence score, validation status.
- **Consent:** grantor, recipient, scope, purpose, created time, expiry, revoked time, status.
- **AuditEvent:** actor, subject type/ID, action, result, request ID, IP/device metadata policy, timestamp, retention class.

Use migrations for all schema changes. Avoid storing raw document text in audit tables.

## 4. Processing state machine

Document states should be explicit and monotonic for each attempt:

`UPLOADED → SCANNING → OCR → CLASSIFYING → EXTRACTING → INDEXING → READY`

Recoverable failures transition to `FAILED` with a safe error category and retry count. A new retry creates a new processing attempt while preserving the prior result for audit/debugging. Unsupported or low-confidence documents can transition to `REVIEW_REQUIRED` instead of `READY`.

Each worker step must:

1. Load the document version by ID.
2. Verify ownership and processing lease.
3. Check idempotency key/version before writing.
4. Produce derived output with a parser/model version.
5. Persist status and metrics transactionally where possible.
6. Emit the next job or a safe failure event.

## 5. API surface

### Health and identity

- `GET /api/health` — liveness/readiness without sensitive details.
- `GET /api/me` — current user and permitted capabilities.

### Documents

- `GET /api/documents` — paginated authorised metadata with category, status, date, and confidence filters.
- `POST /api/documents/upload-url` — validate requested file metadata and return short-lived signed upload information.
- `POST /api/documents` — confirm object upload and create a processing record.
- `GET /api/documents/{id}` — summary, entities, processing state, source references, and authorised preview URL.
- `GET /api/documents/{id}/text` — authorised OCR text where enabled.
- `DELETE /api/documents/{id}` — create a deletion request or delete according to retention policy.

### Questions

- `POST /api/questions` — retrieve authorised chunks, generate answer, validate citations, and return answer status.
- `POST /api/questions/{id}/feedback` — store helpfulness and citation-quality feedback.

### Deadlines

- `GET /api/deadlines` — sorted candidate and confirmed actions.
- `PATCH /api/deadlines/{id}` — confirm, edit, complete, dismiss, or restore an action.

### Privacy and audit

- `GET/POST/DELETE /api/consents` — list, grant, and revoke scoped access.
- `GET /api/audit-events` — current user's paginated event history.
- `POST /api/privacy/export` — create an export job.
- `POST /api/privacy/deletion` — create a deletion request with confirmation.

Use consistent problem responses with error code, request ID, safe message, and field errors. Never reveal another user's resource existence through status or timing differences.

## 6. Security invariants

- Validate OIDC JWT issuer, audience, signature, expiry, and required claims.
- Use OIDC subject IDs, not email addresses, as identity keys.
- Authorise at controller/service/repository boundaries; retrieval filters must include owner, tenant, consent, retention, and role scope.
- Encrypt S3 objects, database backups, queue payloads where applicable, and all transport with TLS.
- Issue short-lived signed URLs with content disposition and content type restrictions.
- Validate file type from content signatures, not only extensions; scan before OCR.
- Apply request size limits, rate limits, idempotency keys, and abuse detection.
- Keep credentials, tokens, raw document content, full prompts, and model responses out of normal logs.
- Present model output as assistance, always cite evidence, and abstain when evidence is insufficient.

## 7. Retrieval and citation controls

1. Authenticate the requester.
2. Build an authorised scope from owner, tenant, role, active consent, and retention state.
3. Apply the scope as a mandatory metadata filter before vector or keyword retrieval.
4. Retrieve chunks with document and page provenance.
5. Reject chunks whose scope cannot be revalidated.
6. Generate an answer only from returned evidence.
7. Validate that each citation points to an evidence chunk included in retrieval.
8. Return an abstention reason for empty, conflicting, stale, or low-confidence evidence.

## 8. Testing strategy

- Unit tests for claim mapping, deadline parsing, state transitions, error mapping, scope construction, and citation validation.
- Repository tests for ownership, consent expiry, retention, pagination, and unique constraints.
- API integration tests for OIDC claims, 401/403 behaviour, signed URL expiry, idempotent uploads, and safe problem responses.
- Worker tests for retries, duplicate jobs, partial failure, parser versioning, and poison messages.
- Security tests for IDOR, cross-user retrieval, prompt injection in documents, malicious files, and log redaction.
- Contract tests to keep frontend API types aligned with backend responses.

## 9. Observability and operations

Track request latency, error rate, queue depth, processing duration by stage, retry count, extraction confidence, citation coverage, abstention rate, signed URL failures, storage usage, and model cost. Use request IDs across API and worker logs. Alert on readiness failures, queue growth, repeated processing failures, suspicious access patterns, and backup failures.

Define runbooks for compromised credentials, object-storage exposure, queue poisoning, incorrect extraction, database restore, provider outage, and POPIA data-subject requests.

## 10. Delivery sequence

1. Add OIDC resource server, user provisioning, and request identity context.
2. Add PostgreSQL migrations, repository tests, and document metadata entities.
3. Add signed upload/download flow, file validation, checksum, and object-storage encryption.
4. Add queue-backed processing state machine, leases, retries, and failure categories.
5. Add OCR, classification, extraction, evidence coordinates, and parser versioning.
6. Add chunking, embeddings, authorised retrieval, citation validation, and abstention.
7. Add deadlines, user corrections, consent, audit events, export/deletion, retention jobs, rate limits, and observability.

