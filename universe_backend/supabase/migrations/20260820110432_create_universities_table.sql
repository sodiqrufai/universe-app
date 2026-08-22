create table universities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short_name text,
  domain text unique,
  city text,
  country text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table universities is 'Universities available on the platform. Students select one during verification.';