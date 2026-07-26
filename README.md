# Folio

Folio is a secure student financial-document workspace. It helps students store funding paperwork, understand obligations, ask source-grounded questions, and track deadlines.

## Stack

- **Frontend:** Next.js 14, React 18, TypeScript, CSS, Lucide React
- **Backend:** Spring Boot 3, Java 21, Spring Web, Spring Data JPA, PostgreSQL
- **Storage / AI plan:** S3-compatible object storage, OCR and extraction worker, retrieval-augmented generation
- **Hosting:** Railway for the Next.js app, Spring API, and PostgreSQL service

## Run the frontend

```bash
npm install
npm run dev
```

Open `http://localhost:3000`. The current UI is a clickable prototype with mocked data and local state.

## Run the backend scaffold

```bash
cd backend
mvn spring-boot:run
```

Health check: `http://localhost:8080/api/health`

For local PostgreSQL and the API:

```bash
docker compose up --build
```

See `docs/DEVELOPMENT.md`, `docs/FRONTEND.md`, `docs/BACKEND.md`, and `docs/RAILWAY.md` for the working plan.
