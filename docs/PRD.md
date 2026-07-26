# Folio product requirements document

## 1. Product summary

Folio is a secure student-finance document workspace. It helps students collect, understand, search, and act on funding-related paperwork without manually opening and comparing multiple PDFs.

The product combines a document vault, extraction pipeline, source-grounded question answering, deadline tracking, and privacy controls. The system must make the original source visible whenever it presents an extracted fact or AI-generated answer.

## 2. Problem statement

Students often receive fragmented documents from NSFAS, universities, bursary providers, banks, and appeal offices. Important amounts, conditions, dates, and next steps may be hidden in long documents or expressed in inconsistent language. Missing one deadline can affect registration, funding, examination access, or accommodation.

Folio addresses this by turning documents into an organised, searchable record while preserving a clear link back to the original source. It is an assistance product, not a financial-advice, payment, or automated-submission system.

## 3. Goals and non-goals

### Goals

- Give each student one secure place for financial-aid documents.
- Reduce the time needed to locate a document, amount, condition, or deadline.
- Extract useful facts while preserving page, passage, and bounding-box provenance.
- Answer questions only from documents the current user is authorised to access.
- Make upcoming obligations visible and actionable.
- Provide privacy, consent, audit, retention, export, and deletion foundations aligned with POPIA.

### Non-goals

- Giving regulated financial, legal, or academic advice.
- Submitting forms, making payments, changing funding records, or contacting institutions automatically.
- Allowing staff to browse student records without explicit consent and role-based access.
- Training a general-purpose model on student documents.
- Replacing the official source document or the institution's authoritative financial system.

## 4. Users and personas

### Primary persona: funded student

A student receives NSFAS funding, an institutional bursary, scholarship, or loan. They need to know what was approved, what they owe, what conditions apply, and what must be submitted next. They may use a mobile device and may have limited time or inconsistent connectivity.

**Needs:** fast retrieval, plain-language summaries, trustworthy citations, deadline reminders, secure access, and clear recovery when processing fails.

### Secondary persona: authorised financial-aid staff

A staff member may review a student summary only after the student grants explicit, time-bound consent and the staff account has the appropriate role. Staff must not receive unrestricted access to source files by default.

**Needs:** scoped access, consent history, read-only review, revocation, auditability, and clear separation between student-owned data and staff operations.

### Operational persona: product/support operator

An internal operator monitors processing failures, queue health, costs, and incidents without reading document contents unless a documented support procedure and authorisation allow it.

## 5. Core user journeys

### Journey A: first secure sign-in

1. Student enters their institutional email and password through the Eduvos OIDC flow.
2. Identity provider completes MFA.
3. Folio maps the stable OIDC subject to a local user record.
4. Student lands on the dashboard with an empty-state explanation if no documents exist.
5. A security audit event records session creation without storing credentials or raw tokens.

### Journey B: upload and understand a document

1. Student selects a PDF, DOCX, or supported image.
2. Client requests a short-lived signed upload URL.
3. Client validates size and type before uploading directly to object storage.
4. API creates a document record with `UPLOADED` processing state.
5. Worker scans, extracts text, classifies the document, identifies entities, calculates confidence, and derives candidate deadlines.
6. UI shows progress, processing errors, retry action, and the completed summary.
7. Student can inspect each extracted fact and open the source page or passage.

### Journey C: ask a grounded question

1. Student asks a question in plain language.
2. API authenticates the user and retrieves only authorised chunks.
3. Retrieval applies document, tenant, consent, and retention filters before model generation.
4. Answer service returns an answer, citations, confidence, and an abstention message when evidence is insufficient.
5. Student can open each cited source and rate the answer.

### Journey D: complete a deadline

1. Worker derives an action and due date from a document.
2. Student reviews the source and confirms or edits the candidate task.
3. Dashboard displays urgency, source document, due date, and required action.
4. Student marks the task complete or records that it is not applicable.
5. The system records the state change and keeps the original extracted evidence.

### Journey E: consent-based staff review

1. Student chooses which summary or document scope to share.
2. Student selects recipient, purpose, and expiry.
3. API records consent and issues scoped access.
4. Staff sees only the permitted material.
5. Student can revoke access; future requests fail immediately and the audit trail remains.

## 6. Functional requirements

### Identity and sessions

- Support Eduvos OIDC authorization-code flow with MFA handled by the identity provider.
- Use OIDC subject identifiers as stable user keys; never use email as the primary identity key.
- Expire sessions and signed URLs; support logout and token revocation.
- Return clear 401 and 403 states without revealing whether another user's document exists.

### Document intake

- Support PDF, DOCX, JPEG, and PNG in the MVP, with configurable maximum size.
- Reject unsupported types, oversized files, corrupted files, and malware-positive files before processing.
- Store source objects with tenant/user prefixes, encryption, retention metadata, and a generated checksum.
- Display upload progress and allow retry without duplicating a completed document.

### Processing and extraction

- Track explicit states: `UPLOADED`, `SCANNING`, `OCR`, `CLASSIFYING`, `EXTRACTING`, `INDEXING`, `READY`, and `FAILED`.
- Store classification, confidence, summary, extracted entities, source page, text offsets, and optional bounding boxes.
- Preserve the original file as the source of truth; derived data must be replaceable when a parser version changes.
- Route low-confidence or unsupported documents to a review state rather than presenting uncertain values as facts.

### Vault and search

- List only documents visible to the authenticated user and active consent scopes.
- Filter by category, processing state, date, and confidence.
- Search titles, extracted entities, and authorised OCR text.
- Show loading, empty, error, retry, and processing states.

### Grounded Q&A

- Accept questions about funding, fees, conditions, documents, and deadlines.
- Return citations with document title, page/passage, and confidence where available.
- Abstain when retrieval is empty, contradictory, stale, or below the configured evidence threshold.
- Never expose retrieved chunks from an unauthorised document.
- Record question and answer metadata for quality and abuse monitoring without logging raw sensitive text by default.

### Deadlines and actions

- Derive candidate obligations from extracted dates and action phrases.
- Store source evidence, due date, timezone, confidence, status, and user corrections.
- Sort by urgency and expose overdue, upcoming, completed, dismissed, and uncertain states.
- Avoid sending reminders until the student confirms notification preferences.

### Privacy and audit

- Record document views, downloads, shares, consent changes, exports, deletions, and security events.
- Support data export and deletion workflows with confirmation and retention exceptions documented.
- Prevent raw document contents, credentials, access tokens, and full prompts from application logs.
- Make consent scope, actor, purpose, creation time, expiry, and revocation visible to the student.

## 7. Non-functional requirements

- **Security:** TLS in transit, encrypted object storage, encrypted database backups, least privilege, signed URLs, secret management, dependency scanning, and threat modelling before real documents are accepted.
- **Privacy:** data minimisation, purpose limitation, retention controls, consent, access transparency, and POPIA review for every new data flow.
- **Reliability:** failed processing must be retryable and idempotent; document metadata must not disappear when a worker fails.
- **Performance:** dashboard initial data should render quickly on a normal mobile connection; retrieval should provide a bounded response time and a visible loading state.
- **Accessibility:** keyboard operation, semantic landmarks, visible focus, readable contrast, labelled controls, screen-reader status announcements, and responsive layouts.
- **Observability:** health checks, structured non-sensitive logs, queue metrics, processing latency, error rates, citation coverage, and alert thresholds.
- **Maintainability:** typed API contracts, migrations, automated tests, documented worker versions, and reproducible local setup.

## 8. Acceptance criteria for MVP

- A test user can authenticate through the configured OIDC provider and complete MFA.
- An authorised user can upload a supported document through a signed URL and see processing progress.
- A completed document displays classification, summary, entities, confidence, and source references.
- A second user cannot list, preview, download, retrieve, or ask questions about the first user's document.
- A grounded answer includes at least one verifiable citation or clearly abstains.
- Extracted deadlines include source evidence and can be confirmed, corrected, completed, or dismissed.
- Audit events exist for access, upload, download, Q&A, consent, export, and deletion actions.
- The frontend and API expose usable error, empty, retry, loading, and unauthorised states.

## 9. Success measures

- Median time to find a target document: under 10 seconds.
- Median time to identify the next action: under 30 seconds.
- Citation coverage for grounded answers: 100% of non-abstained answers.
- Unauthorised access test success: 100% of isolation cases blocked.
- Extraction precision and recall measured separately by document type before pilot launch.
- Student-reported trust and answer helpfulness measured after each pilot task.
- Processing failure rate and median processing duration tracked by file type and parser version.

## 10. Release boundaries

### Prototype release

Mock authentication, simulated processing, seeded documents, responsive UI, and no real student data.

### Secure pilot release

Real OIDC, signed object storage, PostgreSQL metadata, worker processing, access controls, audit trail, and a controlled research cohort.

### Operational release

Notifications, consent-based staff review, export/deletion, monitoring, backups, incident response, cost controls, and documented support procedures.

## 11. Risks and mitigations

- **Incorrect extraction:** show confidence and evidence, abstain below threshold, and provide human review.
- **Data leakage:** enforce authorisation at every API and retrieval boundary, test tenant isolation, and use short-lived URLs.
- **Stale deadlines:** keep source evidence, show extraction time, allow correction, and never imply official status.
- **Model hallucination:** retrieval grounding, citation validation, refusal on insufficient evidence, and answer-quality evaluation.
- **Operational cost growth:** file limits, queue budgets, model routing, retention policies, and per-user rate limits.
- **Identity integration delays:** keep a mocked provider for development while reserving production behaviour for OIDC.

