create table faculties (
  id uuid primary key default gen_random_uuid(),
  university_id uuid not null references universities(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (university_id, name)
);

comment on table faculties is 'Faculties belong to exactly one university.';