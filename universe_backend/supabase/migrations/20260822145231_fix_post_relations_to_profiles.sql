alter table posts drop constraint posts_author_id_fkey;
alter table posts add constraint posts_author_id_fkey
  foreign key (author_id) references profiles(id) on delete cascade;

alter table comments drop constraint comments_author_id_fkey;
alter table comments add constraint comments_author_id_fkey
  foreign key (author_id) references profiles(id) on delete cascade;

alter table reactions drop constraint reactions_user_id_fkey;
alter table reactions add constraint reactions_user_id_fkey
  foreign key (user_id) references profiles(id) on delete cascade;

alter table reports drop constraint reports_reported_by_fkey;
alter table reports add constraint reports_reported_by_fkey
  foreign key (reported_by) references profiles(id) on delete cascade;