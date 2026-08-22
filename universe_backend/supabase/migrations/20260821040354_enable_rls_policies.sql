alter table profiles enable row level security;

create policy "Users can view their own profile"
on profiles for select
using (auth.uid() = id);

create policy "Users can update their own profile"
on profiles for update
using (auth.uid() = id);

create policy "Users can insert their own profile"
on profiles for insert
with check (auth.uid() = id);


alter table universities enable row level security;
alter table faculties enable row level security;
alter table departments enable row level security;
alter table courses enable row level security;

create policy "Anyone can read universities" on universities for select using (true);
create policy "Anyone can read faculties" on faculties for select using (true);
create policy "Anyone can read departments" on departments for select using (true);
create policy "Anyone can read courses" on courses for select using (true);