create table service_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  icon text
);

create table services (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references profiles(id) on delete cascade,
  category_id uuid references service_categories(id),
  university_id uuid references universities(id),
  title text not null,
  description text,
  price numeric(10,2),
  price_type text not null default 'fixed' check (price_type in ('fixed', 'hourly', 'negotiable')),
  status text not null default 'active' check (status in ('active', 'paused', 'removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table service_images (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references services(id) on delete cascade,
  image_url text not null,
  sort_order int not null default 0
);

create table service_bookings (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references services(id) on delete cascade,
  customer_id uuid not null references profiles(id) on delete cascade,
  message text,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table service_reports (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references services(id) on delete cascade,
  reported_by uuid not null references profiles(id),
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now()
);

alter table service_categories enable row level security;
alter table services enable row level security;
alter table service_images enable row level security;
alter table service_bookings enable row level security;
alter table service_reports enable row level security;

create policy "Anyone can read service categories" on service_categories for select using (true);

create policy "Anyone authenticated can read services" on services for select using (auth.uid() is not null);
create policy "Users can create their own services" on services for insert with check (auth.uid() = provider_id);
create policy "Users can update their own services" on services for update using (auth.uid() = provider_id);
create policy "Users can delete their own services" on services for delete using (auth.uid() = provider_id);

create policy "Anyone authenticated can read service images" on service_images for select using (auth.uid() is not null);

create policy "Users can read bookings they're involved in"
on service_bookings for select
using (auth.uid() = customer_id or auth.uid() in (select provider_id from services where services.id = service_bookings.service_id));

create policy "Customers can create bookings" on service_bookings for insert with check (auth.uid() = customer_id);

create policy "Users can report services" on service_reports for insert with check (auth.uid() = reported_by);