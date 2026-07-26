# Folio roadmap

This roadmap is ordered by risk: establish a useful interface first, then protect real data, then add intelligence, then add operational scale. A phase may overlap another phase, but its exit criteria must be met before real student documents move to the next trust boundary.

## Phase 0 — Prototype and product foundation

**Outcome:** a reviewable, responsive product experience with no real student data.

### Product and UX

- Finalise the PRD, primary student journeys, non-goals, acceptance criteria, and research measures.
- Validate dashboard, vault, detail, Q&A, deadlines, security, upload, and mobile navigation flows.
- Add loading, empty, error, retry, forbidden, and processing states to the prototype.
- Confirm source evidence is visible for every simulated extraction and answer.

### Engineering foundation

- Keep the Next.js app build reproducible from the repository root and deployment platform.
- Split stable UI features from the monolithic prototype as network state is introduced.
- Define typed API contracts, error codes, document states, and audit actions.
- Keep Spring Boot, PostgreSQL, Docker Compose, and Railway deployment scaffolding current.

### Exit criteria

- Production build passes locally and in deployment preview.
- Mobile and keyboard review is complete for primary flows.
- No real documents, secrets, or production credentials are used.
- Phase 1 contracts and security decisions are documented.

## Phase 1 — Secure pilot foundation

**Outcome:** one authorised student can use Folio with real metadata and encrypted source storage.

### Identity and access

- Implement Eduvos OIDC authorization-code flow and provider-managed MFA.
- Provision local user records from stable OIDC subjects.
- Add session expiry, logout, role boundaries, and generic 401/403/not-found states.
- Add automated cross-user and IDOR tests before enabling documents.

### Document intake

- Add upload URL request, file signature/type/size checks, checksum, direct object upload, and completion callback.
- Configure encrypted object storage, private bucket policy, lifecycle retention, and short-lived signed URLs.
- Persist document metadata, ownership, upload attempts, processing state, and audit events.

### Processing baseline

- Add queue-backed state machine for scanning, OCR, classification, extraction, indexing, ready, failed, and retry states.
- Add synthetic test documents for NSFAS, bursary, fee, bank, and appeal categories.
- Connect vault, detail, upload progress, and deadline screens to API state.

### Exit criteria

- OIDC and MFA work in a controlled environment.
- A supported test document can be uploaded, processed, inspected, and deleted.
- Ownership and signed URL tests block unauthorised access.
- API, worker, database, storage, and frontend health checks are visible.

## Phase 2 — Trusted intelligence

**Outcome:** extracted information and answers are useful, measurable, and evidence-bound.

### Extraction quality

- Build a labelled evaluation set by document category, layout, language variation, and scan quality.
- Version OCR, classification, entity, summary, and deadline parsers.
- Store page, passage, offset, and bounding-box provenance.
- Add confidence thresholds and a human review queue for uncertain output.

### Retrieval-grounded Q&A

- Chunk OCR content with document/page provenance.
- Generate embeddings and store scope metadata with every chunk.
- Apply owner, tenant, consent, retention, and role filters before retrieval.
- Validate citations and implement abstention for missing, contradictory, stale, or low-confidence evidence.
- Add student helpfulness and citation-quality feedback.

### Exit criteria

- Extraction precision/recall is measured by document type.
- Every non-abstained answer has a verifiable citation.
- Prompt injection, cross-user retrieval, and citation spoofing tests pass.
- Low-confidence documents are not presented as authoritative facts.

## Phase 3 — Pilot operations and privacy workflows

**Outcome:** Folio can operate safely for a controlled student cohort.

### Notifications and deadlines

- Let students confirm, edit, dismiss, and complete extracted obligations.
- Add notification preferences, reminder schedules, timezone handling, and opt-out.
- Keep reminders linked to source evidence and label uncertain dates clearly.

### Consent and staff access

- Implement scoped, purpose-bound, time-limited consent grants.
- Add staff read-only views, revocation, access expiry, and complete audit history.
- Prevent staff search or retrieval outside active consent and role scope.

### POPIA and operations

- Add export and deletion request workflows with retention exceptions.
- Configure backups, restore tests, rate limits, incident response, support runbooks, and cost budgets.
- Add non-sensitive monitoring for latency, failures, queue depth, storage, model cost, and access anomalies.

### Exit criteria

- Pilot support owner, incident owner, and data-protection responsibilities are assigned.
- Export, deletion, consent revocation, audit, and backup restoration are tested.
- Synthetic-data staging is isolated from pilot data.
- Pilot metrics meet the product success thresholds in `PRD.md`.

## Phase 4 — Expansion and optimisation

**Outcome:** validated Folio workflows can serve additional institutions and form factors.

### Product expansion

- Add configurable institution taxonomies, document templates, terminology, and retention policies.
- Evaluate Flutter mobile client only if research confirms native demand beyond responsive web.
- Add multilingual content and accessibility improvements based on participant testing.
- Add institution-specific integrations only after ownership, consent, and data-sharing boundaries are approved.

### Platform scale

- Improve parser routing, caching, model selection, batching, and cost controls.
- Add tenant-level administration without weakening student ownership boundaries.
- Introduce disaster recovery targets, regional storage decisions, and formal service-level objectives.

### Exit criteria

- New institution onboarding does not require code changes to core security rules.
- Accessibility, privacy, security, and extraction regression suites pass.
- Cost per processed document and support burden remain within approved limits.

## Cross-phase dependencies

- OIDC and ownership precede real document storage.
- Signed URLs and malware scanning precede source previews.
- Provenance precedes trustworthy summaries and Q&A.
- Authorisation filters precede vector retrieval and staff access.
- Retention and audit design precede production pilot data.
- Evaluation data precedes claims about extraction or answer quality.

