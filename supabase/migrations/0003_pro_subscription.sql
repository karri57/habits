-- Pro subscription status. Not in the original spec — added for the
-- Delivery Habits PRO paywall (Plaid bank sync is Pro-gated; manual tracking
-- stays free). Written by the client after a verified purchase/restore via
-- in_app_purchase, so it persists across devices tied to the account rather
-- than living only in on-device store state.
alter table public.users
  add column if not exists is_pro boolean not null default false,
  add column if not exists pro_expires_at timestamptz;
