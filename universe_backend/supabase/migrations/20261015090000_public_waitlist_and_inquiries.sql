-- Public (not-logged-in) signups from the marketing landing page.
-- The existing waitlist_entries table is for logged-in users only (it
-- requires a profile id), so landing-page visitors get their own tables.
-- RLS is on with NO policies: only the backend (service role) can read or
-- write these. View them in the Supabase table editor or via the admin API.

create table if not exists waitlist_signups (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  university_id uuid not null references universities(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (email, university_id)
);
alter table waitlist_signups enable row level security;
create index if not exists waitlist_signups_university_idx on waitlist_signups (university_id);

create table if not exists partner_inquiries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  organization text,
  email text not null,
  message text not null,
  created_at timestamptz not null default now()
);
alter table partner_inquiries enable row level security;
