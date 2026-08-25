create table conversations (
  id uuid primary key default gen_random_uuid(),
  is_group boolean not null default false,
  name text,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table conversation_participants (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  last_read_at timestamptz,
  joined_at timestamptz not null default now(),
  unique (conversation_id, user_id)
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  content text,
  attachment_url text,
  created_at timestamptz not null default now()
);

create table blocked_users (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_id)
);

create table chat_reports (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) on delete cascade,
  reported_user_id uuid references profiles(id),
  reported_by uuid not null references profiles(id),
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now()
);

alter table conversations enable row level security;
alter table conversation_participants enable row level security;
alter table messages enable row level security;
alter table blocked_users enable row level security;
alter table chat_reports enable row level security;

-- A user can only see conversations/messages they're actually part of.
create policy "Participants can view their conversations"
on conversations for select
using (id in (select conversation_id from conversation_participants where user_id = auth.uid()));

create policy "Users can create conversations"
on conversations for insert
with check (auth.uid() = created_by);

create policy "Participants can view participant lists of their conversations"
on conversation_participants for select
using (conversation_id in (select conversation_id from conversation_participants where user_id = auth.uid()));

create policy "Users can add themselves as participants"
on conversation_participants for insert
with check (auth.uid() = user_id);

create policy "Users can update their own participant row"
on conversation_participants for update
using (auth.uid() = user_id);

create policy "Participants can view messages in their conversations"
on messages for select
using (conversation_id in (select conversation_id from conversation_participants where user_id = auth.uid()));

create policy "Participants can send messages in their conversations"
on messages for insert
with check (auth.uid() = sender_id and conversation_id in (select conversation_id from conversation_participants where user_id = auth.uid()));

create policy "Users can manage their own blocks"
on blocked_users for select using (auth.uid() = blocker_id);

create policy "Users can block others"
on blocked_users for insert with check (auth.uid() = blocker_id);

create policy "Users can unblock others"
on blocked_users for delete using (auth.uid() = blocker_id);

create policy "Users can report chats"
on chat_reports for insert with check (auth.uid() = reported_by);