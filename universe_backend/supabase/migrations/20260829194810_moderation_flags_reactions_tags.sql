alter table posts add column is_removed boolean not null default false;
alter table posts add column removed_reason text;
alter table posts add column tags text[];
alter table posts add column type text not null default 'post' check (type in ('post', 'notice'));

alter table anonymous_posts add column is_removed boolean not null default false;
alter table anonymous_posts add column removed_reason text;

alter table events drop constraint events_status_check;
alter table events add constraint events_status_check check (status in ('active', 'cancelled', 'removed'));

alter table reactions add column reaction_type text not null default 'like' check (reaction_type in ('like', 'love'));
alter table reactions drop constraint reactions_post_id_user_id_key;
alter table reactions add constraint reactions_post_id_user_id_reaction_type_key unique (post_id, user_id, reaction_type);

create index idx_posts_created_at on posts (created_at desc);
create index idx_posts_tags on posts using gin (tags);

drop policy "Users can insert their own posts" on posts;
create policy "Users can insert their own posts, notices require elevated role"
on posts for insert
with check (
  auth.uid() = author_id
  and (type = 'post' or auth.uid() in (select id from profiles where role in ('moderator','university_admin','super_admin')))
);