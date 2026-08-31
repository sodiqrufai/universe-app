create table comment_reactions (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references comments(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);

alter table comment_reactions enable row level security;
create policy "Anyone authenticated can read comment reactions" on comment_reactions for select using (auth.uid() is not null);
create policy "Users can react to comments" on comment_reactions for insert with check (auth.uid() = user_id);
create policy "Users can remove their own comment reactions" on comment_reactions for delete using (auth.uid() = user_id);

alter table anonymous_comments add column parent_comment_id uuid references anonymous_comments(id) on delete cascade;

create table anonymous_comment_reactions (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references anonymous_comments(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);

alter table anonymous_comment_reactions enable row level security;
create policy "Anyone authenticated can read anonymous comment reactions" on anonymous_comment_reactions for select using (auth.uid() is not null);
create policy "Users can react to anonymous comments" on anonymous_comment_reactions for insert with check (auth.uid() = user_id);
create policy "Users can remove their own anonymous comment reactions" on anonymous_comment_reactions for delete using (auth.uid() = user_id);

alter table announcements add column sent_by uuid references profiles(id);

create table follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references profiles(id) on delete cascade,
  followed_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (follower_id, followed_id),
  check (follower_id != followed_id)
);

alter table follows enable row level security;
create policy "Anyone authenticated can read follows" on follows for select using (auth.uid() is not null);
create policy "Users can follow others" on follows for insert with check (auth.uid() = follower_id);
create policy "Users can unfollow" on follows for delete using (auth.uid() = follower_id);

alter table profiles add constraint profiles_level_check
  check (level is null or level in ('100L','200L','300L','400L','500L','Postgraduate'));

alter table profiles add column username_lower text generated always as (lower(username)) stored;
create unique index profiles_username_lower_unique on profiles (username_lower) where username is not null;