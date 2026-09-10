create extension if not exists pgcrypto;

create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique check (email = lower(email)),
  display_name text not null check (char_length(display_name) between 1 and 120),
  password_hash text not null,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.otp_challenges (
  id uuid primary key,
  user_id uuid not null references public.app_users(id) on delete cascade,
  purpose text not null check (purpose in ('REGISTER', 'LOGIN')),
  code_hash text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0 check (attempts between 0 and 5),
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists otp_challenges_user_created_idx on public.otp_challenges(user_id, created_at desc);

create table if not exists public.user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists user_sessions_token_idx on public.user_sessions(token_hash);

create table if not exists public.vault_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 240),
  category text not null default 'Fee Statement',
  original_name text,
  storage_path text unique,
  mime_type text,
  byte_size bigint check (byte_size is null or byte_size between 1 and 20971520),
  status text not null default 'UPLOADING' check (status in ('UPLOADING','UPLOADED','SCANNING','OCR','CLASSIFYING','EXTRACTING','INDEXING','READY','REVIEW_REQUIRED','FAILED')),
  page_number integer not null default 1 check (page_number > 0),
  page_count integer not null default 1 check (page_count > 0),
  content text,
  summary text,
  entities jsonb not null default '[]'::jsonb,
  confidence numeric(5,4) check (confidence is null or confidence between 0 and 1),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((storage_path is null and original_name is null) or (storage_path is not null and original_name is not null))
);
create index if not exists vault_documents_user_created_idx on public.vault_documents(user_id, created_at desc);
create index if not exists vault_documents_active_user_idx on public.vault_documents(user_id, created_at desc) where deleted_at is null;

create table if not exists public.ai_queries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,
  grounded boolean not null,
  abstained boolean not null,
  model text,
  source_count integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists ai_queries_user_created_idx on public.ai_queries(user_id, created_at desc);

alter table public.app_users enable row level security;
alter table public.otp_challenges enable row level security;
alter table public.user_sessions enable row level security;
alter table public.vault_documents enable row level security;
alter table public.ai_queries enable row level security;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('folio-documents', 'folio-documents', false, 20971520, array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document','image/jpeg','image/png'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.verify_folio_otp(
  p_challenge_id uuid,
  p_code_hash text,
  p_session_token_hash text,
  p_session_expires_at timestamptz
) returns table(status text, user_id uuid, email text, display_name text)
language plpgsql
security definer
set search_path = public
as $$
declare
  challenge public.otp_challenges%rowtype;
  account public.app_users%rowtype;
begin
  select * into challenge from public.otp_challenges where id = p_challenge_id for update;
  if not found then return query select 'NOT_FOUND'::text, null::uuid, null::text, null::text; return; end if;
  if challenge.consumed_at is not null then return query select 'USED'::text, null::uuid, null::text, null::text; return; end if;
  if challenge.expires_at <= now() then return query select 'EXPIRED'::text, null::uuid, null::text, null::text; return; end if;
  if challenge.attempts >= 5 then return query select 'LOCKED'::text, null::uuid, null::text, null::text; return; end if;
  if challenge.code_hash <> p_code_hash then
    update public.otp_challenges set attempts = least(attempts + 1, 5) where id = p_challenge_id;
    return query select 'INVALID'::text, null::uuid, null::text, null::text; return;
  end if;

  update public.otp_challenges set consumed_at = now() where id = p_challenge_id;
  if challenge.purpose = 'REGISTER' then update public.app_users set verified = true where id = challenge.user_id; end if;
  select * into account from public.app_users where id = challenge.user_id;
  if not account.verified then return query select 'UNVERIFIED'::text, null::uuid, null::text, null::text; return; end if;
  insert into public.user_sessions(user_id, token_hash, expires_at) values (account.id, p_session_token_hash, p_session_expires_at);
  return query select 'VERIFIED'::text, account.id, account.email, account.display_name;
end;
$$;

revoke all on function public.verify_folio_otp(uuid,text,text,timestamptz) from public, anon, authenticated;
grant execute on function public.verify_folio_otp(uuid,text,text,timestamptz) to service_role;

-- No client policies are intentional. All access is mediated by authenticated Vercel routes using the service role.
