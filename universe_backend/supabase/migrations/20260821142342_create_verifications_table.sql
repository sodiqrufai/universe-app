create table verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  matric_number text not null,
  university_id uuid not null references universities(id),
  document_path text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  rejection_reason text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table verifications enable row level security;

create policy "Users can view their own verification"
on verifications for select
using (auth.uid() = user_id);

create policy "Users can insert their own verification"
on verifications for insert
with check (auth.uid() = user_id);