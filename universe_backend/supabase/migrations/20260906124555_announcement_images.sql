alter table announcements add column image_url text;

-- Bucket 'announcement-images' must be created manually in the Supabase
-- dashboard (Storage -> New bucket -> Public ON), same as every other bucket
-- in this project -- these policies alone don't create the bucket itself.

create policy "Admins can upload announcement images"
on storage.objects for insert
with check (
  bucket_id = 'announcement-images'
  and auth.uid() in (select id from profiles where role in ('moderator','university_admin','super_admin'))
);

create policy "Anyone can view announcement images"
on storage.objects for select
using (bucket_id = 'announcement-images');
