-- Follow-up to 20260831234304_uniosun_departments_courses.sql -- Nursing
-- was missing from College of Health Sciences (reported directly by a
-- UNIOSUN student during review). Same idempotent insert pattern as the
-- rest of that migration.

insert into departments (faculty_id, name)
select f.id, 'Nursing Science'
from faculties f
join universities u on u.id = f.university_id
where u.name = 'Osun State University'
  and f.name = 'College of Health Sciences'
on conflict (faculty_id, name) do nothing;
