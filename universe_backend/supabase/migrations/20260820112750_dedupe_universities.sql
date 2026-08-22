delete from universities a
using universities b
where a.name = b.name
  and a.ctid > b.ctid;

alter table universities
  add constraint universities_name_unique unique (name);