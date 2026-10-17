-- Ensures the public bucket the backend uploads stories to exists.
-- Safe to run even if you already created it by hand in the dashboard.
insert into storage.buckets (id, name, public)
values ('story-media', 'story-media', true)
on conflict (id) do update set public = true;
