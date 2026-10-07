create table if not exists public.passkey_credentials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.app_users(id) on delete cascade,
  credential_id text not null unique,
  public_key text not null,
  counter bigint not null default 0,
  transports text[] not null default '{}',
  created_at timestamptz not null default now(),
  last_used_at timestamptz
);
create index if not exists passkey_credentials_user_idx on public.passkey_credentials(user_id);

create table if not exists public.passkey_challenges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.app_users(id) on delete cascade,
  challenge text not null,
  purpose text not null check (purpose in ('REGISTER', 'LOGIN')),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists passkey_challenges_lookup_idx on public.passkey_challenges(challenge, purpose, created_at desc);

alter table public.passkey_credentials enable row level security;
alter table public.passkey_challenges enable row level security;
