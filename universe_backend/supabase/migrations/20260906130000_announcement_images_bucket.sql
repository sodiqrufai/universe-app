-- Follow-up to 20260906124555_announcement_images.sql, which left bucket
-- creation as a manual dashboard step. This project already has a better,
-- fully migration-tracked pattern for that (see
-- 20260831071853_voice_notes_bucket_and_chat_report_fix.sql) -- adopting it
-- here too instead of relying on a manual step that's easy to forget across
-- environments. Safe to run whether or not the bucket was already created
-- manually, since `on conflict do nothing` makes this idempotent.

insert into storage.buckets (id, name, public)
values ('announcement-images', 'announcement-images', true)
on conflict (id) do nothing;
