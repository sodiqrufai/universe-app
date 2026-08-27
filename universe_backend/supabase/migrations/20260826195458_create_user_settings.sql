create table user_settings (
  user_id uuid primary key references profiles(id) on delete cascade,
  profile_visibility text not null default 'everyone' check (profile_visibility in ('everyone', 'university_only')),
  allow_messages boolean not null default true,
  notify_chat boolean not null default true,
  notify_marketplace boolean not null default true,
  notify_events boolean not null default true,
  notify_community boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table user_settings enable row level security;

create policy "Users can view their own settings"
on user_settings for select using (auth.uid() = user_id);

create policy "Users can insert their own settings"
on user_settings for insert with check (auth.uid() = user_id);

create policy "Users can update their own settings"
on user_settings for update using (auth.uid() = user_id);