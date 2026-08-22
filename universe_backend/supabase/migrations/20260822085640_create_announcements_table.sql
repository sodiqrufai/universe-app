create table announcements (
  id uuid primary key default gen_random_uuid(),
  university_id uuid references universities(id),
  title text not null,
  body text not null,
  is_global boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table announcements is 'university_id set = campus-specific. is_global true = shown to all students everywhere.';

alter table announcements enable row level security;

create policy "Anyone can read announcements" on announcements for select using (true);