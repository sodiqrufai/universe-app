alter table universities
  add column ownership_type text not null default 'federal'
  check (ownership_type in ('federal', 'state', 'private'));

update universities set ownership_type = 'private' where name = 'Covenant University';