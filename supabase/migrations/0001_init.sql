-- Delivery Habits schema. Run via `supabase db push` after `supabase link`,
-- or paste into the Supabase SQL editor for a fresh project.

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  -- Not in the original spec, but the Home dashboard greeting ("Good Morning, [First Name]")
  -- needs somewhere to read a display name from.
  first_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  plaid_account_id text unique,
  institution_name text not null,
  account_name text not null,
  type text not null,
  current_balance numeric(12, 2) not null default 0,
  last_synced_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  account_id uuid references public.accounts (id) on delete set null,
  merchant_name text not null,
  amount numeric(12, 2) not null,
  date date not null,
  platform text check (platform in ('doordash', 'ubereats', 'grubhub', 'other')),
  is_food_delivery boolean not null default false,
  source text not null check (source in ('plaid', 'manual')),
  note text,
  -- Lets the Plaid sync function upsert idempotently instead of duplicating
  -- transactions on every sync (null for manual entries).
  plaid_transaction_id text unique,
  created_at timestamptz not null default now()
);

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  -- One budget per user (v1); enables upsert-by-user_id from the Budget screen.
  user_id uuid not null unique references public.users (id) on delete cascade,
  monthly_income numeric(12, 2),
  monthly_budget_amount numeric(12, 2) not null,
  cycle_start_day int not null default 1 check (cycle_start_day between 1 and 28),
  notify_at_75 boolean not null default true,
  notify_at_100 boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.daily_summaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  date date not null,
  amount_spent numeric(12, 2) not null default 0,
  amount_saved numeric(12, 2) not null default 0,
  unique (user_id, date)
);

create index if not exists transactions_user_date_idx on public.transactions (user_id, date desc);
create index if not exists daily_summaries_user_date_idx on public.daily_summaries (user_id, date desc);

alter table public.users enable row level security;
alter table public.accounts enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.daily_summaries enable row level security;

create policy "Users can manage their own row" on public.users
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "Users can manage their own accounts" on public.accounts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can manage their own transactions" on public.transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can manage their own budgets" on public.budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users can manage their own daily summaries" on public.daily_summaries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Auto-create a public.users row whenever someone signs up via Supabase Auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, email, first_name)
  values (new.id, new.email, new.raw_user_meta_data ->> 'first_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
