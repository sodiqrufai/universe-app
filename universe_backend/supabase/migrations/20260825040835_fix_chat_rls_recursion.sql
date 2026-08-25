create or replace function my_conversation_ids()
returns setof uuid
language sql
security definer
stable
as $$
  select conversation_id from conversation_participants where user_id = auth.uid();
$$;

drop policy "Participants can view their conversations" on conversations;
create policy "Participants can view their conversations"
on conversations for select
using (id in (select my_conversation_ids()));

drop policy "Participants can view participant lists of their conversations" on conversation_participants;
create policy "Participants can view participant lists of their conversations"
on conversation_participants for select
using (conversation_id in (select my_conversation_ids()));

drop policy "Participants can view messages in their conversations" on messages;
create policy "Participants can view messages in their conversations"
on messages for select
using (conversation_id in (select my_conversation_ids()));

drop policy "Participants can send messages in their conversations" on messages;
create policy "Participants can send messages in their conversations"
on messages for insert
with check (auth.uid() = sender_id and conversation_id in (select my_conversation_ids()));