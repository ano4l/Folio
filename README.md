# Folio — Secure Student Financial Document Workspace

Folio is an end-to-end secure student financial-document workspace designed to help students manage funding paperwork, understand financial award conditions, query document contents with grounded AI, and track critical deadline obligations.

---

## Architecture & Ecosystem Overview

The Folio workspace is structured as a modular multi-tier monorepo:

- **Frontend (`/frontend`)**: Next.js 14 (App Router), React 18, TypeScript, TailwindCSS, Lucide React, and Radix UI. Built as a responsive web client supporting desktop multi-column layouts and mobile-optimized interfaces.
- **Backend (`/backend`)**: Spring Boot 3, Java 21, Spring Security (OIDC/OAuth2), Spring Data JPA, Flyway migrations, and PostgreSQL. Serves REST APIs for document metadata, grounded Q&A retrieval, and POPIA audit event logging.
- **Mobile (`/mobile`)**: Cross-platform mobile app built with Flutter (Dart 3.7+), implementing Apple Human Interface Guidelines (HIG) and a custom Liquid Glass frosted container design system.
- **iOS (`/ios`)**: Native SwiftUI replica of the Flutter app, deployable to a physical iPhone via Xcode with no third-party dependencies.
- **Deliverables (`/Final Deliverables`)**: The submitted module documents — Deliverable 1 (PDF), Deliverables 2 and 3 (DOCX) — plus `exports/` containing every figure rendered from the final Deliverable 3 document.
- **Infrastructure (`/docs/RAILWAY.md`, `docker-compose.yml`)**: Railway hosting for Web, API, and PostgreSQL, backed by S3-compatible private object storage for encrypted document bytes.

---

## Repository Structure

```
Folio/
├── Final Deliverables/   # Submitted documents (Deliverables 1–3) + exports/ figure renders
├── backend/              # Spring Boot 3 REST API (Java 21)
├── frontend/             # Next.js 14 web client
├── mobile/               # Flutter app (iOS / Android / Web)
├── ios/                  # Native SwiftUI replica of the mobile app
├── docs/                 # PRD, engineering guides, progress + diagrams/ (PlantUML sources)
├── scripts/              # Deliverable build & diagram render tooling
└── docker-compose.yml    # Local PostgreSQL + API parity environment
```

---

## Tech Stack & Rationale

| Layer | Technology | Primary Rationale |
|---|---|---|
| **Web Framework** | Next.js 14 (App Router) | Server-side rendering (SSR), layout nesting, static optimization, and fast client navigation. |
| **Mobile Engine** | Flutter 3.x / Dart 3.7 | Single codebase for iOS and Android with pixel-perfect custom Apple HIG / Liquid Glass rendering. |
| **Backend Framework** | Spring Boot 3 (Java 21) | Robust enterprise security (Spring Security OIDC), type-safe JPA persistence, and high-throughput concurrency. |
| **Database** | PostgreSQL 16 + Flyway | Relational integrity for user document ownership, entity extraction schemas, and versioned migrations. |
| **Object Storage** | S3-Compatible Storage | Encrypted-at-rest private bucket storage utilizing short-lived presigned URLs for client uploads and previews. |
| **State Management** | Flutter Provider (`ChangeNotifier`) | Lightweight, zero-boilerplate reactive state model ideal for seamless local state syncing and rapid testing. |

---

## Core Application Routes & Endpoints

### 1. Web Frontend Routes (`/frontend`)
- `/` — Interactive prototype application shell (`FolioApp.tsx`) with dynamic view state switching:
  - **Auth View (`auth` / `mfa`)**: Simulated credentials submission and 6-digit MFA verification flow with countdown timer.
  - **Dashboard View (`dashboard`)**: High-level vault statistics, quick AI search prompt shortcut, recent documents, and urgent deadline alerts.
  - **Document Vault (`documents`)**: Searchable document list categorized by award type with confidence scores and dual-tab detail modal (**Extracted Data** vs **OCR Raw Text**).
  - **Ask AI Grounded Q&A (`ask`)**: Conversational RAG assistant with credit metering, voice input, speech synthesis, and document source citation chips (`[doc_id:page]`).
  - **Deadline Tracker (`deadlines`)**: Actionable timeline and calendar views for pending bursary/fee obligations with completion toggles.
  - **Security & Privacy (`security`)**: POPIA-compliant security settings, MFA toggles, and immutable access ledger event stream.

### 2. Mobile Screens & Routes (`/mobile`)
- `LoginScreen` (`/login`) — Biometric Face ID / Fingerprint verification (`local_auth`) + 6-digit passcode input (`pinput`).
- `MainShell` (`/shell`) — Translucent frosted `AppBar` header + floating Liquid Glass capsule bottom navigation dock (`_DockItem`).
- `DashboardScreen` (`index: 0`) — Glass stat widgets, AI prompt shortcut banner, recent documents, urgent deadline highlights.
- `DocumentsScreen` (`index: 1`) — Document list cards, Cupertino upload sheet (`_UploadSheet`), and `DocumentDetailView` with `CupertinoSlidingSegmentedControl` (Extracted Data vs OCR Raw Text).
- `AskAiScreen` (`index: 2`) — Frosted credit quota bar, iOS Messages style chat bubbles, speech recognition (`speech_to_text`), text-to-speech reader (`flutter_tts`), and grounded citation chips.
- `DeadlinesScreen` (`index: 3`) — `TableCalendar` month view + pending obligation list with resolution triggers.
- `SecurityScreen` (`index: 4`) — `CupertinoSwitch` toggles for MFA/Biometrics/Sharing + immutable POPIA access timeline.

### 3. Backend REST API Endpoints (`/backend`)
- `GET /api/health` — System readiness and health check.
- `POST /api/v1/auth/login` & `POST /api/v1/auth/mfa/verify` — OAuth2/OIDC authentication endpoints.
- `GET /api/v1/documents` — Paginated list of student documents filtered by ownership scope.
- `POST /api/v1/documents/upload-url` — Generates presigned S3 upload URL for direct client intake.
- `GET /api/v1/documents/{id}` — Retrieves document detail, AI summary, and extracted key-value entities.
- `GET /api/v1/documents/{id}/preview` — Generates 15-minute presigned URL for document preview.
- `POST /api/v1/ai/ask` — RAG question answering pipeline returning grounded text and verified citations.
- `GET /api/v1/deadlines` & `PATCH /api/v1/deadlines/{id}/complete` — Fetches and resolves deadline items.
- `GET /api/v1/audit-logs` — Returns append-only POPIA audit events queryable by student ID.

---

## Engineering Method Rationale ("Why We Built It This Way")

### Why Direct S3 Presigned Uploads over Multipart API Proxying?
Buffering large PDF/image binary uploads through a Spring Boot backend exhausts JVM heap memory and blocks API threads under high concurrent load. Generating client-side presigned S3 URLs lets Web and Mobile clients stream uploads directly to encrypted object storage. The backend only processes light metadata callbacks once upload completion is verified.

### Why Dual-Tab "Extracted Data" vs "OCR Raw Text"?
Financial aid decisions depend on exact terms (award amounts, renewal dates, GPA requirements). Standard AI summaries risk hallucination or misinterpretation. Providing a dual-tab detail view allows students to view AI-extracted structured entities side-by-side with raw, monospaced OCR source text and bounding-box page evidence for 100% verification trust.

### Why Grounded RAG with Explicit Abstention?
Generic LLM chat can produce plausible but incorrect answers about student fees or funding rules. Folio's retrieval service extracts relevant document chunks bounded by user authorization scopes. If document chunks do not contain sufficient evidence, the model is prompted to explicitly abstain rather than guess, attaching verifiable citation chips (`[doc_id:page]`) to every answer.

### Why Provider over Riverpod/Bloc in Mobile?
Flutter's native `Provider` pattern with `ChangeNotifier` (`AppState`) provides a transparent reactive model without code generation overhead (`freezed` / `build_runner`). This minimizes complexity, accelerates mobile development iterations, and maintains clean state synchronization across screens.

### Why Apple Liquid Glass & HIG Design Language?
Handling financial paperwork produces student stress. Implementing Apple Human Interface Guidelines—using frosted backdrop blurs (`ImageFilter.blur`), hair-line specular borders, continuous squircle corners (`BorderRadius.circular(20)`), and floating capsule navigation docks—creates an ultra-premium, trustworthy experience that reduces anxiety around sensitive paperwork.

### Why Immutable Audit Ledgers for POPIA Compliance?
South Africa's Protection of Personal Information Act (POPIA) mandates transparent tracking of personal information processing. Every document upload, view, deletion, AI query, and consent change generates an immutable, timestamped event in PostgreSQL, providing students with full visibility into how their data is accessed.

---

## Infrastructure & Deployment Strategy

- **Railway Hosting**: Next.js Web Frontend, Spring Boot API, and PostgreSQL database are co-located on Railway for low internal network latency.
- **Docker Parity**: Local development via `docker-compose.yml` mimics the production Railway environment with matching PostgreSQL and environment secrets.

---

## Quick Start Instructions

### 1. Web Frontend
```bash
npm install
npm run dev
```
Open [http://localhost:3000](http://localhost:3000) in your browser.

### 2. Backend Service
```bash
cd backend
mvn spring-boot:run
```
Health check endpoint: `http://localhost:8080/api/health`

For local PostgreSQL & Docker setup:
```bash
docker compose up --build
```

### 3. Flutter Mobile App
```bash
cd mobile
flutter pub get
flutter run -d chrome # or macos / ios / android
```

---

## Documentation Index

- `docs/PRD.md` — Product Requirements Document & Persona Specs
- `docs/DEVELOPMENT.md` — Engineering Guidelines & Setup
- `docs/FRONTEND.md` — Next.js Frontend Architecture
- `docs/BACKEND.md` — Spring Boot API Architecture
- `docs/RAILWAY.md` — Production Infrastructure & Railway Deployment
- `docs/progress.md` — Working Delivery Plan & Release Gates
- `docs/diagrams/` — PlantUML sources and PNG renders for all system-model figures
- `Final Deliverables/` — Final submitted module documents and figure exports
