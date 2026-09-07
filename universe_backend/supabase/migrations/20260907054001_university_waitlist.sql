alter table universities add column is_pilot boolean not null default false;

update universities set is_pilot = true where name = 'Osun State University';

create table waitlist_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  requested_university_id uuid not null references universities(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id)
  -- One active waitlist request per user, not per (user, university) --
  -- a student shouldn't be able to sit on multiple simultaneous waitlist
  -- entries for different schools; joining a new one should replace, not
  -- stack. Enforced via upsert on user_id in the endpoint below.
);

alter table waitlist_entries enable row level security;

create policy "Users can view their own waitlist entry"
on waitlist_entries for select using (auth.uid() = user_id);

create policy "Users can join the waitlist for themselves"
on waitlist_entries for insert with check (auth.uid() = user_id);

create policy "Users can update their own waitlist entry"
on waitlist_entries for update using (auth.uid() = user_id);

create policy "Users can leave the waitlist"
on waitlist_entries for delete using (auth.uid() = user_id);
