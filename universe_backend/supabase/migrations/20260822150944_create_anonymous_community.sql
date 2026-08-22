create table anonymous_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references profiles(id) on delete cascade,
  anonymous_username text not null unique,
  created_at timestamptz not null default now()
);

create table anonymous_posts (
  id uuid primary key default gen_random_uuid(),
  anonymous_profile_id uuid not null references anonymous_profiles(id) on delete cascade,
  category text not null default 'talk' check (category in ('rant', 'advice', 'confession', 'talk')),
  content text not null,
  created_at timestamptz not null default now()
);

create table anonymous_comments (
  id uuid primary key default gen_random_uuid(),
  anonymous_post_id uuid not null references anonymous_posts(id) on delete cascade,
  anonymous_profile_id uuid not null references anonymous_profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create table anonymous_reports (
  id uuid primary key default gen_random_uuid(),
  anonymous_post_id uuid references anonymous_posts(id) on delete cascade,
  anonymous_comment_id uuid references anonymous_comments(id) on delete cascade,
  reported_by uuid not null references profiles(id),
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now()
);

alter table anonymous_profiles enable row level security;
alter table anonymous_posts enable row level security;
alter table anonymous_comments enable row level security;
alter table anonymous_reports enable row level security;

-- Critical: a user can only ever see or create THEIR OWN anonymous_profiles row.
-- This is what makes "who owns this anonymous post" undiscoverable by regular users.
create policy "Users can view only their own anonymous profile"
on anonymous_profiles for select
using (auth.uid() = user_id);

create policy "Users can create only their own anonymous profile"
on anonymous_profiles for insert
with check (auth.uid() = user_id);

-- Posts and comments are readable by anyone logged in (the content itself, not the link to a real identity).
create policy "Anyone authenticated can read anonymous posts" on anonymous_posts for select using (auth.uid() is not null);
create policy "Anyone authenticated can read anonymous comments" on anonymous_comments for select using (auth.uid() is not null);

create policy "Users can insert their own anonymous reports"
on anonymous_reports for insert
with check (auth.uid() = reported_by);