create table event_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table events (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references profiles(id) on delete cascade,
  category_id uuid references event_categories(id),
  university_id uuid references universities(id),
  title text not null,
  description text,
  location text,
  starts_at timestamptz not null,
  cover_image_url text,
  status text not null default 'active' check (status in ('active', 'cancelled')),
  created_at timestamptz not null default now()
);

create table event_rsvps (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  status text not null check (status in ('interested', 'going')),
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create table event_reports (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  reported_by uuid not null references profiles(id),
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now()
);

alter table event_categories enable row level security;
alter table events enable row level security;
alter table event_rsvps enable row level security;
alter table event_reports enable row level security;

create policy "Anyone can read event categories" on event_categories for select using (true);

create policy "Anyone authenticated can read events" on events for select using (auth.uid() is not null);
create policy "Users can create events" on events for insert with check (auth.uid() = organizer_id);
create policy "Organizers can update their own events" on events for update using (auth.uid() = organizer_id);

create policy "Anyone authenticated can read rsvps" on event_rsvps for select using (auth.uid() is not null);
create policy "Users can rsvp themselves" on event_rsvps for insert with check (auth.uid() = user_id);
create policy "Users can update their own rsvp" on event_rsvps for update using (auth.uid() = user_id);
create policy "Users can remove their own rsvp" on event_rsvps for delete using (auth.uid() = user_id);

create policy "Users can report events" on event_reports for insert with check (auth.uid() = reported_by);