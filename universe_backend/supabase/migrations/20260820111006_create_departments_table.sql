create table departments (
  id uuid primary key default gen_random_uuid(),
  faculty_id uuid not null references faculties(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (faculty_id, name)
);

comment on table departments is 'Departments belong to exactly one faculty.';