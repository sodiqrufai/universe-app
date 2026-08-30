-- 20260830_settings_messages_feed_additions.sql

-- Settings: locale preference (scope decision: storage only, not full i18n)
alter table profiles add column locale text not null default 'en';

-- Messages: soft delete per participant, delivery tracking, voice notes
alter table conversation_participants add column left_at timestamptz;
-- A participant who has "deleted" a conversation just gets a left_at timestamp;
-- the conversation and messages remain fully intact for the other participant(s).
-- Inbox/message queries must filter out conversations where left_at is set for
-- the requesting user, and re-sending a message to a conversation should clear
-- left_at for the recipient again (so it reappears for them) -- handled in app code.

alter table messages add column delivered_at timestamptz;
alter table messages add column media_type text check (media_type in ('image', 'audio'));
alter table messages add column duration_seconds integer;

create table message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references messages(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  reaction_type text not null default 'like' check (reaction_type in ('like', 'love')),
  created_at timestamptz not null default now(),
  unique (message_id, user_id, reaction_type)
);

alter table message_reactions enable row level security;

create policy "Participants can read reactions in their conversations"
on message_reactions for select
using (message_id in (
  select id from messages where conversation_id in (select my_conversation_ids())
));

create policy "Participants can react to messages in their conversations"
on message_reactions for insert
with check (
  auth.uid() = user_id
  and message_id in (select id from messages where conversation_id in (select my_conversation_ids()))
);

create policy "Users can remove their own message reactions"
on message_reactions for delete using (auth.uid() = user_id);

-- Feed: saved posts, reposts
create table saved_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  post_id uuid not null references posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, post_id)
);

alter table saved_posts enable row level security;
create policy "Users can manage their own saved posts"
on saved_posts for select using (auth.uid() = user_id);
create policy "Users can save posts" on saved_posts for insert with check (auth.uid() = user_id);
create policy "Users can unsave posts" on saved_posts for delete using (auth.uid() = user_id);

alter table posts add column reposted_post_id uuid references posts(id) on delete set null;
-- on delete set null (not cascade) is deliberate: if the original post is deleted,
-- the repost itself should survive and the feed should render it as
-- "original post no longer available" rather than vanishing outright.