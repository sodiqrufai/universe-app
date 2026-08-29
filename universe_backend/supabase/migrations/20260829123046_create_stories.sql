-- 20260827000000_create_stories.sql

create table stories (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  university_id uuid references universities(id),
  media_url text not null,
  media_type text not null check (media_type in ('image', 'video')),
  caption text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create table story_views (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references stories(id) on delete cascade,
  viewer_id uuid not null references profiles(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  unique (story_id, viewer_id)
);

alter table stories enable row level security;
alter table story_views enable row level security;

-- Mirrors posts visibility: readable if global-scope OR same university.
-- Stories don't have a "global" flag in this MVP — visibility is tied to the author's
-- own university, or NULL university_id (treated as globally visible, same convention
-- posts uses for accounts with no university set).
create policy "Users can read stories from their university or global"
on stories for select
using (
  auth.uid() is not null
  and (
    university_id is null
    or university_id in (select university_id from profiles where id = auth.uid())
  )
);

create policy "Users can create their own stories"
on stories for insert
with check (auth.uid() = author_id);

create policy "Users can delete their own stories"
on stories for delete
using (auth.uid() = author_id);

create policy "Users can read story views on stories they can see"
on story_views for select
using (
  story_id in (
    select id from stories
    where university_id is null
       or university_id in (select university_id from profiles where id = auth.uid())
  )
);

create policy "Users can record their own views"
on story_views for insert
with check (auth.uid() = viewer_id);

create policy "Users can update their own view timestamp"
on story_views for update
using (auth.uid() = viewer_id);