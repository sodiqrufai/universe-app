alter table reports add column target_type text;
alter table reports add column target_id uuid;
alter table reports add column reported_user_id uuid references profiles(id);
alter table reports add column resolution_note text;
alter table reports add column resolved_by uuid references profiles(id);
alter table reports add column resolved_at timestamptz;

update reports set target_type = 'post', target_id = post_id where post_id is not null;
update reports set target_type = 'comment', target_id = comment_id where comment_id is not null and target_type is null;

alter table reports alter column target_type set not null;
alter table reports alter column target_id set not null;
alter table reports add constraint reports_target_type_check
  check (target_type in ('post', 'comment', 'anonymous_post', 'listing', 'service', 'event', 'chat'));

insert into reports (target_type, target_id, reported_by, reason, status, created_at)
select 'anonymous_post', coalesce(anonymous_post_id, anonymous_comment_id), reported_by, reason, status, created_at
from anonymous_reports;

insert into reports (target_type, target_id, reported_by, reason, status, created_at)
select 'listing', listing_id, reported_by, reason, status, created_at
from listing_reports;

insert into reports (target_type, target_id, reported_by, reason, status, created_at)
select 'service', service_id, reported_by, reason, status, created_at
from service_reports;

insert into reports (target_type, target_id, reported_by, reason, status, created_at)
select 'event', event_id, reported_by, reason, status, created_at
from event_reports;

insert into reports (target_type, target_id, reported_user_id, reported_by, reason, status, created_at)
select 'chat', conversation_id, reported_user_id, reported_by, reason, status, created_at
from chat_reports;

drop table anonymous_reports;
drop table listing_reports;
drop table service_reports;
drop table event_reports;
drop table chat_reports;