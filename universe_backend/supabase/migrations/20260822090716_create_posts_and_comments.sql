create table posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  image_url text,
  visibility text not null default 'university' check (visibility in ('university', 'global')),
  university_id uuid references universities(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  parent_comment_id uuid references comments(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create table reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references posts(id) on delete cascade,
  comment_id uuid references comments(id) on delete cascade,
  reported_by uuid not null references auth.users(id),
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now()
);

alter table posts enable row level security;
alter table comments enable row level security;
alter table reactions enable row level security;
alter table reports enable row level security;

create policy "Anyone authenticated can read posts" on posts for select using (auth.uid() is not null);
create policy "Users can insert their own posts" on posts for insert with check (auth.uid() = author_id);
create policy "Users can delete their own posts" on posts for delete using (auth.uid() = author_id);

create policy "Anyone authenticated can read comments" on comments for select using (auth.uid() is not null);
create policy "Users can insert their own comments" on comments for insert with check (auth.uid() = author_id);
create policy "Users can delete their own comments" on comments for delete using (auth.uid() = author_id);

create policy "Anyone authenticated can read reactions" on reactions for select using (auth.uid() is not null);
create policy "Users can insert their own reactions" on reactions for insert with check (auth.uid() = user_id);
create policy "Users can delete their own reactions" on reactions for delete using (auth.uid() = user_id);

create policy "Users can insert their own reports" on reports for insert with check (auth.uid() = reported_by);