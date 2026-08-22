create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  university_id uuid references universities(id),
  faculty_id uuid references faculties(id),
  department_id uuid references departments(id),
  full_name text,
  username text unique,
  matric_number text,
  level text,
  bio text,
  avatar_url text,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table profiles is 'One profile per authenticated user, linked 1:1 to auth.users.';