alter table profiles add column role text not null default 'student'
  check (role in ('student', 'moderator', 'university_admin', 'super_admin'));

update profiles set role = 'super_admin' where is_admin = true;

alter table profiles add column is_suspended boolean not null default false;
alter table profiles add column restricted_until timestamptz;

create table admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references profiles(id),
  action text not null,
  target_type text not null,
  target_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

alter table admin_audit_log enable row level security;

create policy "Admins can read audit log"
on admin_audit_log for select
using (auth.uid() in (select id from profiles where role in ('moderator','university_admin','super_admin')));