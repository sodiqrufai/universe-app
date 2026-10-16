-- In-app feedback (bug / idea / other). Auth is optional on the endpoint, so user_id can be null.
-- RLS on, no policies: only the backend (service role) reads/writes. Viewed through the admin API.
create table if not exists feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  message text not null check (char_length(message) between 3 and 2000),
  category text not null check (category in ('bug','idea','other')),
  screen text,
  app_version text,
  platform text,
  status text not null default 'new' check (status in ('new','reviewed','closed')),
  created_at timestamptz not null default now()
);
alter table feedback enable row level security;
create index if not exists feedback_created_idx on feedback (created_at desc);
create index if not exists feedback_category_idx on feedback (category);

-- Lets the admin portal track which partner inquiries have been answered.
alter table partner_inquiries
  add column if not exists status text not null default 'new'
  check (status in ('new','contacted','closed'));
create index if not exists partner_inquiries_status_idx on partner_inquiries (status);
