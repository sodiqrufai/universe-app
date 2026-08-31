insert into storage.buckets (id, name, public)
values ('chat-voice-notes', 'chat-voice-notes', true)
on conflict (id) do nothing;

create policy "Users can upload voice notes"
on storage.objects for insert
with check (bucket_id = 'chat-voice-notes' and auth.uid() is not null);

create policy "Authenticated users can listen to voice notes"
on storage.objects for select
using (bucket_id = 'chat-voice-notes' and auth.uid() is not null);

alter table reports alter column target_id drop not null;

alter table reports add constraint reports_target_or_user_present
  check (target_id is not null or reported_user_id is not null);