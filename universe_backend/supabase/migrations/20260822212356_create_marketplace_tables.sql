create table marketplace_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  icon text
);

create table listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references profiles(id) on delete cascade,
  category_id uuid references marketplace_categories(id),
  university_id uuid references universities(id),
  title text not null,
  description text,
  price numeric(10,2) not null,
  condition text check (condition in ('new', 'like_new', 'good', 'fair', 'used')),
  status text not null default 'active' check (status in ('active', 'sold', 'removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table listing_images (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  image_url text not null,
  sort_order int not null default 0
);

create table saved_listings (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (listing_id, user_id)
);

create table offers (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  buyer_id uuid not null references profiles(id) on delete cascade,
  amount numeric(10,2) not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now()
);

create table listing_reports (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references listings(id) on delete cascade,
  reported_by uuid not null references profiles(id),
  reason text not null,
  status text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now()
);

alter table marketplace_categories enable row level security;
alter table listings enable row level security;
alter table listing_images enable row level security;
alter table saved_listings enable row level security;
alter table offers enable row level security;
alter table listing_reports enable row level security;

create policy "Anyone can read categories" on marketplace_categories for select using (true);

create policy "Anyone authenticated can read listings" on listings for select using (auth.uid() is not null);
create policy "Users can create their own listings" on listings for insert with check (auth.uid() = seller_id);
create policy "Users can update their own listings" on listings for update using (auth.uid() = seller_id);
create policy "Users can delete their own listings" on listings for delete using (auth.uid() = seller_id);

create policy "Anyone authenticated can read listing images" on listing_images for select using (auth.uid() is not null);

create policy "Users can manage their own saved listings" on saved_listings for select using (auth.uid() = user_id);
create policy "Users can save listings" on saved_listings for insert with check (auth.uid() = user_id);
create policy "Users can unsave listings" on saved_listings for delete using (auth.uid() = user_id);

create policy "Users can read offers on their listings or their own offers"
on offers for select
using (auth.uid() = buyer_id or auth.uid() in (select seller_id from listings where listings.id = offers.listing_id));

create policy "Users can make offers" on offers for insert with check (auth.uid() = buyer_id);

create policy "Users can report listings" on listing_reports for insert with check (auth.uid() = reported_by);