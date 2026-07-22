-- Stores Plaid access tokens server-side only. Not in the original data model,
-- but required to sync transactions after the initial link — Plaid access
-- tokens must never reach the Flutter client, so this table has RLS enabled
-- with zero policies (nothing granted to `anon`/`authenticated`); only Edge
-- Functions using the service-role key can read or write it.
create table if not exists public.plaid_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  item_id text not null unique,
  access_token text not null,
  institution_name text not null,
  -- /transactions/sync cursor, so re-syncs only fetch what changed.
  sync_cursor text,
  created_at timestamptz not null default now()
);

alter table public.plaid_items enable row level security;

create index if not exists plaid_items_user_idx on public.plaid_items (user_id);
