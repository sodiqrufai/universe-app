-- =====================================================================
-- UniVerse DEMO CONTENT  (for usability testing)
-- ---------------------------------------------------------------------
-- WHAT IT DOES
--   Adds ~12 posts, 6 anonymous posts, 6 marketplace listings, 4 services,
--   4 events and 3 announcements so the app does not look empty to testers.
--
-- BEFORE YOU RUN IT
--   Create/sign up at least ONE real account at your pilot university
--   (the university with is_pilot = true) and finish its sign-up. Demo
--   content is written under up to 5 of those accounts (so it looks like a
--   few different people; if only one exists, everything is under that one).
--   Tip: use your own test accounts; testers will see these names on posts.
--
-- HOW TO RUN
--   Supabase dashboard -> SQL Editor -> paste this whole file -> Run.
--   Safe to run once. Running it twice adds a second copy.
--
-- HOW TO REMOVE IT LATER
--   Run seed/remove_demo_content.sql. Every row this script creates is
--   recorded in the table seed_demo_rows, so removal deletes ONLY demo data.
--
-- NOT SEEDED: education resources (they need real uploaded files).
-- =====================================================================

create table if not exists seed_demo_rows (
  table_name text not null,
  row_id uuid not null,
  created_at timestamptz not null default now()
);
alter table seed_demo_rows enable row level security;

do $$
declare
  v_uni uuid;
  v_people uuid[];
  v_n int;
  v_id uuid;
  v_aid uuid;
  i int;
  rec record;

  -- pick the i-th person, wrapping around
  pick uuid;
begin
  select id into v_uni from universities where is_pilot = true order by name limit 1;
  if v_uni is null then
    raise exception 'No pilot university found (universities.is_pilot = true). Mark your pilot campus first.';
  end if;

  select coalesce(array_agg(id), '{}') into v_people
  from (select id from profiles where university_id = v_uni and username is not null order by created_at limit 5) p;
  v_n := coalesce(array_length(v_people, 1), 0);
  if v_n = 0 then
    raise exception 'No finished accounts at the pilot university yet. Sign up and complete onboarding with at least one account first, then run this again.';
  end if;

  -- ---------------- posts ----------------
  i := 0;
  for rec in
    select * from (values
      ('Welcome to UniVerse, UNIOSUN! Drop a post and tell us what is happening on campus this week.', 'university', array['Welcome','Campus'], interval '70 hours'),
      ('Study group for Calculus II tonight 7pm, Library 2nd floor. Bring your jotters and past questions.', 'university', array['Calculus','StudyGroup'], interval '52 hours'),
      ('Does anyone have the GST 102 past questions? Even the 2023 set will do. Please share.', 'university', array['GST','PastQuestions'], interval '47 hours'),
      ('Light went off again in the hostel. How are you all coping with night reading?', 'university', array['Hostel','Power'], interval '40 hours'),
      ('Found: a black Casio calculator in the Faculty of Science lecture hall B. Message me to claim it.', 'university', array['LostAndFound'], interval '33 hours'),
      ('Reminder: course registration closes Friday. Do not wait for the last minute, the portal gets slow.', 'university', array['Registration'], interval '28 hours'),
      ('Cafeteria today: jollof or fried rice? Rate it for the people who have not eaten yet.', 'university', array['Food'], interval '22 hours'),
      ('Starting a beginner coding club. Python basics, Saturdays 4pm. Comment if you are interested.', 'university', array['Tech','Coding'], interval '17 hours'),
      ('Which department has the best hostel football team this season? Defend your department.', 'university', array['Sports','Football'], interval '11 hours'),
      ('Tip: back up your assignments to Google Drive before exam season. Phones disappear, files should not.', 'university', array['Tips'], interval '8 hours'),
      ('Selling my lab coat (size M), barely used. Needed it only for one semester. DM if interested.', 'university', array['Labcoat','Marketplace'], interval '5 hours'),
      ('Which Nigerian campus has the best food? Let us settle it once and for all.', 'global', array['Campus','Food'], interval '3 hours')
    ) as t(content, visibility, tags, ago)
  loop
    i := i + 1;
    pick := v_people[((i - 1) % v_n) + 1];
    insert into posts (author_id, content, visibility, university_id, tags, created_at, updated_at)
    values (pick, rec.content, rec.visibility, v_uni, rec.tags, now() - rec.ago, now() - rec.ago)
    returning id into v_id;
    insert into seed_demo_rows values ('posts', v_id);
  end loop;

  -- ---------------- anonymous posts ----------------
  -- one anonymous persona per available account (a person has a single persona)
  i := 0;
  for rec in
    select * from (values
      ('rant',       'Why is the portal always down exactly when registration is about to close?', interval '30 hours'),
      ('advice',     'Anyone know a cheap and reliable place to print near campus?',               interval '26 hours'),
      ('confession', 'I slept through my own 8am test and somehow still passed. Please do not copy me.', interval '20 hours'),
      ('talk',       'Lecture hall wifi is actually fast today. Enjoy it while it lasts.',          interval '14 hours'),
      ('advice',     'How do you balance a side hustle with a full course load? I am struggling.',  interval '9 hours'),
      ('rant',       'Group projects where one person does everything and everyone shares the mark. Enough.', interval '4 hours')
    ) as t(category, content, ago)
  loop
    i := i + 1;
    pick := v_people[((i - 1) % v_n) + 1];
    select id into v_aid from anonymous_profiles where user_id = pick;
    if v_aid is null then
      insert into anonymous_profiles (user_id, anonymous_username)
      values (pick, 'demo_anon_' || substr(replace(pick::text, '-', ''), 1, 8))
      returning id into v_aid;
      insert into seed_demo_rows values ('anonymous_profiles', v_aid);
    end if;
    insert into anonymous_posts (anonymous_profile_id, category, content, created_at)
    values (v_aid, rec.category, rec.content, now() - rec.ago)
    returning id into v_id;
    insert into seed_demo_rows values ('anonymous_posts', v_id);
  end loop;

  -- ---------------- marketplace listings ----------------
  i := 0;
  for rec in
    select * from (values
      ('Calculus textbook (Stewart)', 'Clean copy, no torn pages. Good for MTH 101 and 102.', 4500, 'like_new', 'book'),
      ('Mini fridge', 'Works perfectly, ideal for a hostel room. Pickup at the hostel.', 25000, 'good', 'electronic'),
      ('Laptop stand (foldable)', 'Light and sturdy, fits up to 15 inch laptops.', 6000, 'like_new', 'electronic'),
      ('Lab coat, size M', 'Used for one semester only. Washed and ironed.', 3500, 'good', 'cloth'),
      ('Casio fx-991 calculator', 'Original, all functions working, comes with cover.', 7500, 'good', 'electronic'),
      ('Study desk lamp (rechargeable)', 'Three brightness levels, lasts a full night of reading.', 3000, 'new', 'electronic')
    ) as t(title, description, price, condition, cat)
  loop
    i := i + 1;
    pick := v_people[((i - 1) % v_n) + 1];
    insert into listings (seller_id, category_id, university_id, title, description, price, condition, created_at, updated_at)
    values (
      pick,
      (select id from marketplace_categories where name ilike '%' || rec.cat || '%' order by name limit 1),
      v_uni, rec.title, rec.description, rec.price, rec.condition,
      now() - (i * interval '6 hours'), now() - (i * interval '6 hours')
    ) returning id into v_id;
    insert into seed_demo_rows values ('listings', v_id);
  end loop;

  -- ---------------- services ----------------
  i := 0;
  for rec in
    select * from (values
      ('Graphic design: flyers, logos, posters', 'Event flyers, club logos and posters. Quick turnaround, free first revision.', 5000, 'negotiable', 'design'),
      ('Laundry pickup and delivery', 'Wash, dry and fold. Pickup and delivery within the hostels.', 1500, 'fixed', 'laundry'),
      ('Maths and Physics tutoring', 'One-on-one or small group sessions for 100 and 200 level courses.', 2000, 'hourly', 'tutor'),
      ('Assignment typing and printing', 'Typed, formatted and printed. Same-day pickup on campus.', 1000, 'fixed', 'print')
    ) as t(title, description, price, price_type, cat)
  loop
    i := i + 1;
    pick := v_people[((i + 1) % v_n) + 1];
    insert into services (provider_id, category_id, university_id, title, description, price, price_type, created_at, updated_at)
    values (
      pick,
      (select id from service_categories where name ilike '%' || rec.cat || '%' order by name limit 1),
      v_uni, rec.title, rec.description, rec.price, rec.price_type,
      now() - (i * interval '8 hours'), now() - (i * interval '8 hours')
    ) returning id into v_id;
    insert into seed_demo_rows values ('services', v_id);
  end loop;

  -- ---------------- events ----------------
  i := 0;
  for rec in
    select * from (values
      ('AI and Innovation Workshop', 'A hands-on introduction to AI tools for students. Free entry, bring your laptop.', 'Engineering Building, Hall 2', interval '3 days'),
      ('Career Fair', 'Meet employers and alumni, ask questions and collect internship leads.', 'Main Auditorium', interval '6 days'),
      ('Hostel Football Finals', 'The final of the inter-hostel tournament. Come and support your hostel.', 'Sports Complex', interval '4 days'),
      ('Open Mic Night', 'Poetry, music and comedy. Sign up at the door to perform.', 'Student Centre', interval '9 days')
    ) as t(title, description, location, ahead)
  loop
    i := i + 1;
    pick := v_people[((i + 2) % v_n) + 1];
    insert into events (organizer_id, category_id, university_id, title, description, location, starts_at)
    values (
      pick,
      (select id from event_categories order by name limit 1),
      v_uni, rec.title, rec.description, rec.location, now() + rec.ahead
    ) returning id into v_id;
    insert into seed_demo_rows values ('events', v_id);
  end loop;

  -- ---------------- announcements ----------------
  for rec in
    select * from (values
      ('Welcome to the UniVerse pilot', 'You are among the first students on UniVerse. Explore the feed, the marketplace and events, and tell us what you think.', false),
      ('Found a bug? Tell us', 'Something looks wrong or confusing? Send feedback from the app. Every report helps us fix it faster.', false),
      ('Semester reminders', 'Course registration, fee deadlines and exam timetables will be posted here during the semester.', false)
    ) as t(title, body, is_global)
  loop
    insert into announcements (university_id, title, body, is_global, sent_by)
    values (v_uni, rec.title, rec.body, rec.is_global, v_people[1])
    returning id into v_id;
    insert into seed_demo_rows values ('announcements', v_id);
  end loop;

  raise notice 'Demo content added under % account(s).', v_n;
end $$;
