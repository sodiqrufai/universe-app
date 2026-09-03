-- Full-text search infrastructure for Phase 18.
--
-- Migrates the existing ilike('title', '%term%') pattern (marketplace,
-- services, education resources) to real Postgres full-text search, and adds
-- it fresh to posts (content + tags) and events (which had no search at all).
--
-- NOTE on scope: "listings" is the real table name -- there is no separate
-- "marketplace_listings" table in this schema.
--
-- NOTE on "typo tolerance": this migration gives indexed search, multi-field
-- matching, and relevance weighting (via setweight A/B tiers) -- it does NOT
-- give true typo tolerance. That needs Postgres's pg_trgm extension (trigram
-- fuzzy matching), which is a separate feature not built here. Flagging this
-- so it isn't assumed to be covered.
--
-- NOTE on why this uses trigger-maintained columns, not GENERATED ALWAYS AS
-- ... STORED: to_tsvector() depends on the text-search configuration catalog,
-- which Postgres treats as mutable state (someone could ALTER TEXT SEARCH
-- CONFIGURATION). GENERATED STORED columns require a provably immutable
-- expression, and Postgres's validator sees through this regardless of
-- wrapping to_tsvector() in a function labeled IMMUTABLE -- that does not
-- reliably work here (confirmed the hard way: it still fails with the same
-- SQLSTATE 42P17 even through an immutable plpgsql wrapper). A regular column
-- kept in sync by a BEFORE INSERT OR UPDATE trigger sidesteps this entirely --
-- trigger functions have no such restriction and can call to_tsvector()
-- directly. This is the standard, documented pattern for full-text search
-- columns in Postgres.

-- posts --------------------------------------------------------------------

alter table posts add column search_vector tsvector;

create or replace function posts_search_vector_update() returns trigger as $$
begin
  new.search_vector :=
    setweight(to_tsvector('english', coalesce(new.content, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(array_to_string(new.tags, ' '), '')), 'B');
  return new;
end;
$$ language plpgsql;

create trigger posts_search_vector_trigger
  before insert or update on posts
  for each row execute function posts_search_vector_update();

update posts set search_vector =
  setweight(to_tsvector('english', coalesce(content, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(array_to_string(tags, ' '), '')), 'B');

create index idx_posts_search_vector on posts using gin (search_vector);

-- listings -------------------------------------------------------------

alter table listings add column search_vector tsvector;

create or replace function listings_search_vector_update() returns trigger as $$
begin
  new.search_vector :=
    setweight(to_tsvector('english', coalesce(new.title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(new.description, '')), 'B');
  return new;
end;
$$ language plpgsql;

create trigger listings_search_vector_trigger
  before insert or update on listings
  for each row execute function listings_search_vector_update();

update listings set search_vector =
  setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(description, '')), 'B');

create index idx_listings_search_vector on listings using gin (search_vector);

-- services -------------------------------------------------------------

alter table services add column search_vector tsvector;

create or replace function services_search_vector_update() returns trigger as $$
begin
  new.search_vector :=
    setweight(to_tsvector('english', coalesce(new.title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(new.description, '')), 'B');
  return new;
end;
$$ language plpgsql;

create trigger services_search_vector_trigger
  before insert or update on services
  for each row execute function services_search_vector_update();

update services set search_vector =
  setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(description, '')), 'B');

create index idx_services_search_vector on services using gin (search_vector);

-- events -----------------------------------------------------------------

alter table events add column search_vector tsvector;

create or replace function events_search_vector_update() returns trigger as $$
begin
  new.search_vector :=
    setweight(to_tsvector('english', coalesce(new.title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(new.description, '')), 'B');
  return new;
end;
$$ language plpgsql;

create trigger events_search_vector_trigger
  before insert or update on events
  for each row execute function events_search_vector_update();

update events set search_vector =
  setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(description, '')), 'B');

create index idx_events_search_vector on events using gin (search_vector);

-- resources ----------------------------------------------------------------
-- Wasn't in the original table list for this migration, but IS one of the
-- "3 existing ilike search params" being migrated -- included here for
-- consistency rather than leaving it as the one holdout still on ilike.

alter table resources add column search_vector tsvector;

create or replace function resources_search_vector_update() returns trigger as $$
begin
  new.search_vector := to_tsvector('english', coalesce(new.title, ''));
  return new;
end;
$$ language plpgsql;

create trigger resources_search_vector_trigger
  before insert or update on resources
  for each row execute function resources_search_vector_update();

update resources set search_vector = to_tsvector('english', coalesce(title, ''));

create index idx_resources_search_vector on resources using gin (search_vector);
