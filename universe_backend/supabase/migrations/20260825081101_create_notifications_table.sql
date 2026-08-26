create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  data jsonb,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table notifications enable row level security;

create policy "Users can view their own notifications"
on notifications for select
using (auth.uid() = user_id);

create policy "Users can update their own notifications"
on notifications for update
using (auth.uid() = user_id);