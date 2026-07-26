# Frontend plan

## Current implementation

The Next.js frontend recreates the supplied JSX prototype as a maintainable TypeScript experience. It includes the login state, dashboard, document vault, document detail, Ask AI, deadlines, security, upload modal, responsive layout, and toast feedback.

## Design system

- Ink navy `#101A2B` for navigation and high-contrast actions.
- Teal `#0E7C74` for primary actions and trusted/grounded states.
- Amber `#C97A2B` for deadlines and attention states.
- Warm paper `#F7F6F1` for the canvas.
- Fraunces for editorial headings, DM Sans for UI, DM Mono for extracted values.

## Replace prototype state

Create typed API clients for:

- `GET /api/me`
- `GET /api/documents`
- `POST /api/documents/upload-url`
- `GET /api/documents/:id`
- `POST /api/questions`
- `GET /api/deadlines`
- `GET /api/audit-events`

Add request loading, retry, empty, 401, and upload-progress states. Use server state caching once the API is connected. Keep file bytes out of the Next.js server by uploading directly to object storage with a short-lived signed URL.

## Accessibility

Use semantic landmarks, visible focus states, keyboard-operable dialogs, labelled form controls, status announcements for processing/toasts, and sufficient contrast for urgency colors.
