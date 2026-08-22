create table resources (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  uploader_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  resource_type text not null default 'note' check (resource_type in ('note', 'past_question', 'slide', 'other')),
  file_path text not null,
  created_at timestamptz not null default now()
);

create table study_groups (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  name text not null,
  description text,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table study_group_members (
  id uuid primary key default gen_random_uuid(),
  study_group_id uuid not null references study_groups(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  unique (study_group_id, user_id)
);

alter table resources enable row level security;
alter table study_groups enable row level security;
alter table study_group_members enable row level security;

create policy "Anyone authenticated can read resources" on resources for select using (auth.uid() is not null);
create policy "Users can upload their own resources" on resources for insert with check (auth.uid() = uploader_id);

create policy "Anyone authenticated can read study groups" on study_groups for select using (auth.uid() is not null);
create policy "Users can create study groups" on study_groups for insert with check (auth.uid() = created_by);

create policy "Anyone authenticated can read group membership" on study_group_members for select using (auth.uid() is not null);
create policy "Users can join groups themselves" on study_group_members for insert with check (auth.uid() = user_id);
create policy "Users can leave groups themselves" on study_group_members for delete using (auth.uid() = user_id);