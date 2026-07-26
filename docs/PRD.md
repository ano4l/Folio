# Simplified PRD and scope

## Product goal

Give students one secure place to understand funding, bursary, fee, bank, and appeal documents without manually searching through PDFs.

## Users

Primary user: students receiving NSFAS funding, institutional bursaries, scholarships, or student loans. Secondary users are future authorised financial-aid staff, only when explicit consent and role access exist.

## MVP scope

- Eduvos SSO / OIDC sign-in with MFA.
- Secure document upload for PDF, DOCX, and scanned images.
- Document classification, OCR, short summary, extracted entities, and confidence.
- Document vault with type filtering and detail view.
- Source-grounded question answering with citations.
- Deadline and action timeline generated from extracted dates.
- POPIA-oriented security controls and immutable audit events.

## Out of scope for the frontend milestone

- Real authentication, OCR, LLM calls, S3 upload URLs, push notifications, and production persistence.
- Financial advice, automated submissions, payment processing, and staff administration.
- Native mobile app; the prototype includes responsive behavior, while Flutter remains a later delivery option from the source research.

## Success signals

Students can find a document in under 10 seconds, understand the next action without opening the source PDF, and trust an AI answer because the source is visible. Target the first pilot at 100–150 student research participants, aligned with the supplied research material.
