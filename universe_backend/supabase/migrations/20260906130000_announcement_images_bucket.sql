-- Follow-up to 20260906124555_announcement_images.sql, which left bucket
-- creation as a manual dashboard step. This project already has a better,
-- fully migration-tracked pattern for that (see
-- 20260831071853_voice_notes_bucket_and_chat_report_fix.sql) -- adopting it
-- here too instead of relying on a manual step that's easy to forget across
-- environments.
--
-- Uses `do update set public = true` rather than `do nothing`: if the bucket
-- was already created manually (the original instruction) and left private
-- -- a very easy manual step to miss -- `do nothing` would silently leave it
-- broken. This version actually corrects that case: uploads would succeed
-- and the URL would save correctly either way, but a private bucket makes
-- the resulting "public" URL 403 when anyone tries to actually load it,
-- with no error visible anywhere in the app. `do update` fixes that
-- regardless of whether the bucket already existed or in what state.

insert into storage.buckets (id, name, public)
values ('announcement-images', 'announcement-images', true)
on conflict (id) do update set public = true;
