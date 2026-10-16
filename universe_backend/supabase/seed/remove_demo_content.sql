-- Removes ONLY what seed/demo_content.sql created (it logged every row in seed_demo_rows).
-- Real user content is never touched. Dependent rows (reactions, comments, images) go with
-- their parent via ON DELETE CASCADE.
-- Run in Supabase dashboard -> SQL Editor.

do $$
begin
  if to_regclass('public.seed_demo_rows') is null then
    raise notice 'Nothing to remove: seed_demo_rows does not exist.';
    return;
  end if;

  -- children first, then personas created only for the demo
  delete from announcements          where id in (select row_id from seed_demo_rows where table_name = 'announcements');
  delete from events                 where id in (select row_id from seed_demo_rows where table_name = 'events');
  delete from services               where id in (select row_id from seed_demo_rows where table_name = 'services');
  delete from listings               where id in (select row_id from seed_demo_rows where table_name = 'listings');
  delete from anonymous_posts        where id in (select row_id from seed_demo_rows where table_name = 'anonymous_posts');
  delete from anonymous_profiles     where id in (select row_id from seed_demo_rows where table_name = 'anonymous_profiles');
  delete from posts                  where id in (select row_id from seed_demo_rows where table_name = 'posts');

  drop table seed_demo_rows;
  raise notice 'Demo content removed.';
end $$;
