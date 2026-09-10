# Folio on Vercel and Supabase

This is the active pilot deployment path. Vercel runs the Next.js web app and server routes; Supabase supplies PostgreSQL and the private `folio-documents` bucket. Spring Boot and AWS files remain for a later migration.

## 1. Create Supabase resources

1. Create a Supabase project in the intended region.
2. Run `supabase/migrations/202609080001_vercel_identity_and_vault.sql` in the SQL editor.
3. Confirm the five public tables exist, Row Level Security is enabled, and `folio-documents` is private.
4. Copy the project URL, publishable key, and service-role key. The service-role key is server-only and must never use a `NEXT_PUBLIC_` prefix.

Browser clients have no direct table policies. Vercel routes validate the Folio session and owner before using the service role. The publishable key is used only for signed browser-to-Storage upload.

## 2. Configure providers

1. Verify a sending domain in Resend and set `EMAIL_FROM` to an address on it.
2. Create an OpenRouter key and set `OPENROUTER_MODEL`. The default is `openrouter/free`, which routes to an available zero-cost model. Folio requests `data_collection=deny`; enable `OPENROUTER_ZDR=true` only when the selected model has a compatible ZDR endpoint.
3. Generate `AUTH_OTP_PEPPER` with at least 32 random characters. Changing it invalidates outstanding codes.

## 3. Run locally

Copy `.env.example` to `frontend/.env.local`, fill the values, then run:

```powershell
npm ci --prefix frontend
npm --prefix frontend run dev
```


## 4. Deploy on Vercel

1. Import this repository and leave its project root at the repository root; `vercel.json` builds `frontend`.
2. Add every `.env.example` value to the appropriate Preview and Production environments. Set `NEXT_PUBLIC_APP_URL` to the deployed HTTPS origin.
3. Deploy and run the verification checklist. Never paste the service-role key into browser code, source control, screenshots, or support messages.

## 5. Deployment verification

- Register with a fresh address and confirm one OTP email arrives.
- Verify, sign out, and confirm password login requires a new OTP.
- Refresh after login and confirm the secure cookie restores the session.
- Upload a small synthetic PDF and confirm it appears in the private bucket below that user's UUID.
- Confirm a second account cannot list, delete, restore, or query the first account's documents.
- Confirm the assistant abstains before extraction and on unrelated questions.
- Confirm a failed or unsupported model response never becomes an uncited answer.
- Check Vercel logs for secrets or raw document/question content before enabling pilot traffic.

A local build proves compilation only. The pilot is not ready until the migration, provider delivery, object isolation, and deployed flows above have been checked.
