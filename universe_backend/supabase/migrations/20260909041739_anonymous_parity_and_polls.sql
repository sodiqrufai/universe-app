-- Anonymous avatar (separate from the user's real profile picture, matching
-- the identity-separation principle already established for usernames).
alter table anonymous_profiles add column avatar_url text;

-- Post-level reactions for anonymous posts (only comment-level existed before).
create table anonymous_post_reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references anonymous_posts(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

alter table anonymous_post_reactions enable row level security;
create policy "Anyone authenticated can read anonymous post reactions" on anonymous_post_reactions for select using (auth.uid() is not null);
create policy "Users can react to anonymous posts" on anonymous_post_reactions for insert with check (auth.uid() = user_id);
create policy "Users can remove their own anonymous post reactions" on anonymous_post_reactions for delete using (auth.uid() = user_id);

-- Saved anonymous posts (mirrors the existing saved_listings/saved_posts pattern).
create table saved_anonymous_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  post_id uuid not null references anonymous_posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, post_id)
);

alter table saved_anonymous_posts enable row level security;
create policy "Users can manage their own saved anonymous posts" on saved_anonymous_posts for select using (auth.uid() = user_id);
create policy "Users can save anonymous posts" on saved_anonymous_posts for insert with check (auth.uid() = user_id);
create policy "Users can unsave anonymous posts" on saved_anonymous_posts for delete using (auth.uid() = user_id);

-- Reshare, kept structurally isolated within anonymous_posts -- deliberately
-- NOT unified with posts.reposted_post_id. See the accompanying explanation:
-- anonymous_posts is a separate table by design, and this keeps it that way.
alter table anonymous_posts add column reposted_post_id uuid references anonymous_posts(id) on delete set null;

-- Polls. Can attach to either a regular post or an anonymous post, never both
-- -- enforced by the check constraint below rather than trusting app code
-- alone to keep it consistent.
create table polls (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references posts(id) on delete cascade,
  anonymous_post_id uuid references anonymous_posts(id) on delete cascade,
  question text not null,
  options text[] not null,
  created_at timestamptz not null default now(),
  check (
    (post_id is not null and anonymous_post_id is null)
    or (post_id is null and anonymous_post_id is not null)
  )
);

create table poll_votes (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references polls(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  option_index integer not null,
  created_at timestamptz not null default now(),
  unique (poll_id, user_id)
);

alter table polls enable row level security;
alter table poll_votes enable row level security;

create policy "Anyone authenticated can read polls" on polls for select using (auth.uid() is not null);
create policy "Users can create polls on their own posts" on polls for insert
with check (
  auth.uid() is not null
  and (
    (post_id is not null and auth.uid() in (select author_id from posts where posts.id = post_id))
    or (anonymous_post_id is not null and auth.uid() in (
      select user_id from anonymous_profiles
      where anonymous_profiles.id in (select anonymous_profile_id from anonymous_posts where anonymous_posts.id = anonymous_post_id)
    ))
  )
);

create policy "Anyone authenticated can read poll votes" on poll_votes for select using (auth.uid() is not null);
create policy "Users can cast their own poll votes" on poll_votes for insert with check (auth.uid() = user_id);
create policy "Users can change their own poll vote" on poll_votes for update using (auth.uid() = user_id);
