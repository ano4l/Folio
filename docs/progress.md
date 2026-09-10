# Folio development progress and execution plan

This document is the working delivery plan for Folio. It translates the product requirements into implementation phases, feature workstreams, dependencies, verification tasks, and release gates.

## Status legend

- **Complete** — implemented and verified in the current repository.
- **In progress** — actively being built or integrated; not ready for real student data.
- **Planned** — designed but not yet implemented.
- **Blocked** — dependent on an external decision, credential, provider, or preceding feature.

## Current snapshot

**Current release:** prototype with first server-backed slice / version `0.1.0`

**Repository state:** responsive Next.js frontend with Vercel-native APIs, Supabase account/session/document persistence and private uploads, Resend MFA, owner-scoped OpenRouter chat, plus retained Spring Boot/AWS migration scaffolding.

**Data safety:** identity and private source upload now cross the real API boundary, but malware scanning, OCR/extraction, deadlines, audit, and some vault detail state remain simulated. Do not upload real student documents yet.

**Verified:** local frontend production build and backend Maven tests pass. Live Supabase migration, Vercel runtime, Resend delivery, and OpenRouter privacy routing still require configured environments.

**Primary next milestone:** complete the secure pilot foundation before connecting real document bytes or identity provider credentials.

## Phase 0 — Product and prototype foundation

**Goal:** provide a reviewable, responsive experience that demonstrates the complete student journey with synthetic data only.

**Exit gate:** all primary screens work on desktop and mobile; every simulated AI answer has evidence; no real data or secrets are present; the build passes in local and preview environments.

### 0.1 Product requirements and research

- **Status:** Complete.
- **Scope:** define personas, problem statement, goals, non-goals, user journeys, functional requirements, non-functional requirements, acceptance criteria, metrics, risks, and release boundaries.
- **Implementation tasks:**
  1. Keep `docs/PRD.md` aligned with actual product boundaries.
  2. Maintain the research cohort assumption and validate it before pilot claims.
  3. Record decisions that affect consent, retention, model use, and source evidence.
- **Verification:** product review confirms every feature maps to a user journey and acceptance criterion.
- **Dependency:** none.

### 0.2 Responsive application shell

- **Status:** Complete.
- **Scope:** dashboard, sidebar, top bar, mobile bottom navigation, profile menu, screen transitions, design tokens, and toast feedback.
- **Implementation tasks:**
  1. Preserve desktop multi-column hierarchy.
  2. Preserve mobile bottom tab navigation and safe content padding.
  3. Add focus management, route semantics, and deep-link support before production integration.
- **Verification:** keyboard navigation, 320px–1440px viewport review, no horizontal overflow, and production build.
- **Dependency:** API session bootstrap for production route protection.

### 0.3 Registration, email verification, and MFA sessions

- **Status:** In progress; real API flow implemented, provider delivery unverified.
- **Scope:** registration, password login, six-digit Resend email verification/MFA, hashed passwords and OTPs, attempt limits, resend cooldown, revocable database sessions, secure cookies, and sign-out.
- **Implementation tasks:**
  1. Add per-IP/account rate limiting, password reset, session management, and cleanup jobs.
  2. Verify the Resend domain and run inbox/deliverability tests.
  3. Add integration tests for expiry, replay, enumeration resistance, cookie policy, and database restart survival.
- **Verification:** unit coverage exists for registration verification and session creation; live email and deployed security tests remain.
- **Dependency:** verified Resend sender, PostgreSQL, HTTPS deployment, and security review.

### 0.4 Document vault and private intake

- **Status:** In progress; owner-scoped list, private signed upload, completion verification, soft delete, and restore are implemented.
- **Scope:** seeded document cards, categories, confidence, dates, pages, summaries, detail navigation, and upload modal.
- **Implementation tasks:**
  1. Add pagination and processing polling/backoff.
  2. Add content-signature validation, malware scanning, checksum, and idempotent retry.
  3. Add authorised preview/download and persistent recycle-bin listing.
- **Verification:** document list contract tests and cross-user access tests.
- **Dependency:** user identity and document metadata persistence.

### 0.5 Extraction detail and source evidence prototype

- **Status:** Complete as simulation; real extraction planned.
- **Scope:** AI summary, extracted entities, confidence, visual preview, OCR tab, JSON tab, source bounding-box hover state, and mobile extracted-data/source-document switcher.
- **Implementation tasks:**
  1. Define a stable provenance schema for page, passage, offset, and bounding box.
  2. Replace simulated canvas with an authorised preview URL or safe rendered derivative.
  3. Display low-confidence and review-required states without presenting uncertain data as fact.
- **Verification:** every displayed value opens source evidence; missing evidence produces an explicit state.
- **Dependency:** OCR/extraction worker and source object access.

### 0.6 Grounded Q&A service

- **Status:** In progress; real OpenRouter call and owner-scoped keyword retrieval implemented against seeded document rows.
- **Scope:** conversational history, pre-model relevance gate, prompt-injection boundary, abstention, source chips, OpenRouter model configuration, and privacy routing (`data_collection=deny`, ZDR by default).
- **Implementation tasks:**
  1. Replace seeded rows with OCR/page chunks from the real upload pipeline and add embeddings/reranking.
  2. Validate that every model citation marker maps to returned evidence; reject unsupported claims.
  3. Add persisted credit metering, feedback, rate limits, evaluation sets, and provider fallback policy.
- **Verification:** every non-abstained answer has a valid citation; cross-user retrieval tests fail closed.
- **Dependency:** OpenRouter key/model availability now; OCR chunks, embeddings, and evaluation data for pilot quality.

### 0.7 Deadline timeline prototype

- **Status:** Complete as simulation; extraction and persistence planned.
- **Scope:** upcoming actions, urgency, completion simulation, source document association, and audit entry.
- **Implementation tasks:**
  1. Persist candidate deadlines with source evidence and timezone.
  2. Let students confirm, edit, dismiss, and complete deadlines.
  3. Add notification preferences before reminders are sent.
- **Verification:** deadline changes are idempotent, auditable, and never lose original evidence.
- **Dependency:** extraction worker and document metadata API.

### 0.8 Security and audit prototype

- **Status:** Complete as simulation; real audit and consent planned.
- **Scope:** security settings, sharing toggle, audit search/filter, JSON export, encryption messaging, and session indicators.
- **Implementation tasks:**
  1. Replace local audit state with immutable server events.
  2. Add consent scope, recipient, purpose, expiry, revocation, and export/deletion requests.
  3. Redact sensitive values from logs and error telemetry.
- **Verification:** access, upload, download, Q&A, consent, export, deletion, and security events are queryable by the right user.
- **Dependency:** API identity, database schema, retention policy, and privacy review.

## Phase 1 — Secure pilot foundation

**Goal:** one authorised student can use Folio with real metadata and encrypted source storage.

**Exit gate:** managed Folio authentication works, source uploads are private, document ownership is enforced, processing is retryable, and a synthetic document completes the full pipeline.

### 1.1 Identity and access management

- **Status:** In progress; core account/session path implemented.
- **Build:** Folio-managed registration, email verification, password + MFA login, session handling, role model, logout, recovery, and 401/403 responses.
- **Security tests:** OTP expiry/replay/attempts, session expiry/revocation, enumeration, CSRF/CORS, IDOR, cross-user list/detail/download, and revoked consent.
- **Deliverables:** API security configuration, user migration, frontend session provider, auth integration tests, and runbook.

### 1.2 Document metadata and persistence

- **Status:** In progress; Supabase covers users, OTPs, sessions, document ownership/status, private bucket configuration, and AI-query metadata.
- **Build:** migrations and repositories for users, roles, documents, document versions, processing attempts, entities, chunks, deadlines, questions, citations, consents, and audit events.
- **Rules:** use OIDC subject as external identity; use ownership and tenant constraints; never store source bytes in PostgreSQL.
- **Verification:** migration tests, constraints, pagination, ownership queries, retention fields, and safe not-found behavior.

### 1.3 Secure file intake

- **Status:** In progress; signed direct upload and server-side completion verification are implemented, while scanning and file-signature checks remain.
- **Build:** client validation, signed upload URL endpoint, content-signature validation, size limits, checksum, private object key, malware scan handoff, completion callback, and signed preview/download URL.
- **Supported MVP types:** PDF, DOCX, JPEG, and PNG.
- **Verification:** unsupported type, oversized file, corrupted file, duplicate retry, expired URL, wrong content type, malware-positive file, and object isolation tests.

### 1.4 Processing state machine and queue

- **Status:** In progress; authentication, session bootstrap, document listing/upload/recycle operations, and grounded chat use the active same-origin API.
- **Build:** `UPLOADED`, `SCANNING`, `OCR`, `CLASSIFYING`, `EXTRACTING`, `INDEXING`, `READY`, `REVIEW_REQUIRED`, and `FAILED` states; leases, idempotency, retry limits, dead-letter handling, and parser version.
- **Verification:** duplicate jobs, worker restart, timeout, poison message, partial write, retry exhaustion, and safe failure display.

### 1.5 Frontend API integration

- **Status:** Planned.
- **Build:** typed API client, request IDs, server-state cache, upload progress, processing polling/backoff, optimistic deadline updates, and API error mapping.
- **Verification:** loading, empty, error, retry, forbidden, processing, stale response cancellation, and mobile behavior.

## Phase 2 — Trusted intelligence

**Goal:** extraction and question answering are measurable, evidence-bound, and safe to use for a controlled pilot.

**Exit gate:** extraction quality is measured, citations are validated, unauthorised retrieval is impossible in tests, and low-confidence results are clearly handled.

### 2.1 OCR and document classification

- **Status:** Planned.
- **Build:** OCR provider adapter, scanned-image preprocessing, category classifier, page references, parser version, and confidence calibration.
- **Evaluation:** labelled NSFAS, bursary, fee, bank, appeal, clean PDF, scanned PDF, low-quality scan, and varied layout samples.
- **Verification:** category precision/recall, OCR quality, processing latency, provider failure handling, and cost per document.

### 2.2 Entity and summary extraction

- **Status:** Planned.
- **Build:** amount, date, condition, institution, recipient, action, account-purpose, and funding-status extraction with normalised/display values and provenance.
- **Rules:** preserve source text hash, page, offsets, bounding box, confidence, and model/parser version.
- **Verification:** field-level precision/recall, evidence opening, contradictory values, missing values, and review-required thresholds.

### 2.3 Chunking, embeddings, and authorised retrieval

- **Status:** Planned.
- **Build:** page-aware chunks, embedding provider adapter, vector index, keyword fallback, ownership metadata, retention filter, consent filter, and deletion propagation.
- **Security verification:** cross-user retrieval, tenant filter bypass, revoked consent, deleted document, prompt injection, and direct vector query without scope.

### 2.4 Grounded answer generation

- **Status:** Planned.
- **Build:** retrieval context contract, answer generation, citation validation, evidence score, confidence, refusal/abstention reasons, token limits, and rate limits.
- **Verification:** citation coverage, unsupported question, conflicting documents, stale document, malicious instruction inside a document, provider outage, and answer feedback.

### 2.5 Human review and quality operations

- **Status:** Planned.
- **Build:** review queue for low-confidence documents/entities/deadlines, correction audit history, parser regression dataset, and quality dashboard.
- **Verification:** corrected data does not overwrite source evidence and new parser versions can be compared with prior output.

## Phase 3 — Pilot operations and privacy workflows

**Goal:** operate Folio safely for a small research cohort with support, privacy, and recovery processes.

### 3.1 Deadline confirmation and notifications

- **Status:** Planned.
- **Build:** candidate confirmation, edit/dismiss/complete, timezone handling, email/push preference, reminder schedule, overdue state, and opt-out.
- **Verification:** no reminder without consent, duplicate reminder prevention, timezone boundaries, source evidence, and audit events.

### 3.2 Consent-based staff review

- **Status:** Planned.
- **Build:** summary/source scope selection, purpose, recipient, expiry, revocation, read-only staff portal, and access events.
- **Verification:** expired/revoked consent, scope escalation, staff search isolation, download restrictions, and student visibility of access.

### 3.3 POPIA data rights

- **Status:** Planned.
- **Build:** export job, deletion request, retention exceptions, confirmation step, status tracking, object cleanup, derived-index cleanup, and audit retention.
- **Verification:** complete export, partial provider failure, deletion retries, legal hold/retention exception, and no residual retrieval after deletion.

### 3.4 Production operations

- **Status:** Planned.
- **Build:** dashboards, alerts, backups, restore tests, incident runbooks, rate limits, cost budgets, dependency scanning, secret rotation, and release rollback.
- **Verification:** synthetic outage, worker queue growth, database restore, provider outage, compromised URL, credential rotation, and log redaction review.

## Phase 4 — Expansion

**Goal:** extend the validated product without weakening privacy or evidence guarantees.

### 4.1 Institution configuration

- **Status:** Planned.
- **Build:** configurable taxonomies, institution terminology, templates, retention rules, provider settings, and onboarding validation.
- **Gate:** new institution configuration must not bypass shared authorisation or audit rules.

### 4.2 Mobile and accessibility expansion

- **Status:** Planned.
- **Build:** validate responsive web first; evaluate Flutter only if research proves a native requirement; add multilingual and assistive-technology improvements.
- **Gate:** accessibility regression suite and participant testing pass for core journeys.

### 4.3 Platform scale and cost controls

- **Status:** Planned.
- **Build:** batching, parser routing, caching, model routing, per-user quotas, storage lifecycle optimisation, disaster recovery targets, and service-level objectives.
- **Gate:** cost per processed document and support burden stay within approved limits.

## Feature dependency map

| Feature | Must follow | Enables |
|---|---|---|
| OIDC identity | provider configuration | all authorised data access |
| Document metadata | identity and migrations | vault, upload, audit |
| Signed upload | identity and object policy | real source storage |
| Processing queue | document metadata and object storage | OCR and extraction |
| Extraction evidence | OCR and parser versioning | trustworthy detail view and deadlines |
| Retrieval | chunks, embeddings, and scope filters | grounded Q&A |
| Q&A citations | retrieval and provenance | student trust metrics |
| Consent | identity, roles, and audit | staff review |
| Export/deletion | retention and storage/index adapters | pilot privacy compliance |
| Notifications | confirmed deadlines and preferences | operational reminders |

## Definition of done for each feature

- Product behavior and acceptance criteria are documented.
- UI includes loading, empty, error, retry, forbidden, and processing states where applicable.
- API contract, permission scope, state transitions, and audit event are defined.
- Source provenance is retained for extracted or generated content.
- Unit, integration, security, and relevant end-to-end tests pass.
- Mobile, keyboard, screen-reader, and sensitive-data review is complete.
- Metrics and alerting are defined for production behavior.
- `docs/PRD.md`, `docs/FRONTEND.md`, `docs/BACKEND.md`, `docs/ROADMAP.md`, and this file remain consistent.
- The change is committed with a focused message and linked verification evidence.

## Weekly execution checklist

- Review the next incomplete item and its dependencies.
- Confirm no work is using real student documents or production credentials prematurely.
- Update implementation status and evidence in this file.
- Run frontend build and backend tests relevant to the change.
- Review access-control and logging implications.
- Record blockers, decisions, and next actions before ending the work session.
