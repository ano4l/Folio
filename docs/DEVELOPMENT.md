# Folio development guide

## Repository layout

- `app/` — Next.js app router entry points and global styling.
- `src/components/FolioApp.tsx` — prototype application shell, screens, state, and interactions.
- `backend/` — Spring Boot API scaffold.
- `docs/` — product, delivery, frontend, backend, and hosting decisions.
- `folio-student-finance-prototype.jsx` — original UI reference supplied for the build.

## Local workflow

1. Install Node.js 20+ and Java 21.
2. Run `npm install` and `npm run dev` for frontend work.
3. Run `mvn spring-boot:run` from `backend/` for API work.
4. Use `docker compose up` when a local PostgreSQL database is needed.
5. Keep credentials in environment variables; never commit `.env` files.

## Quality bar

- Preserve the Folio visual language: ink/navy, warm paper background, teal actions, amber urgency, Fraunces headings, and compact data-dense cards.
- Every AI answer must show a source document and passage/page reference.
- Treat uploaded financial documents as sensitive personal information. Do not log file contents or model prompts.
- Add tests for new API contracts and user-critical flows before replacing prototype state with network calls.

## Definition of done

A feature is ready when its UI state is implemented, loading/error/empty states are present, API contracts are documented, security implications are reviewed, and the relevant build/test commands pass.
