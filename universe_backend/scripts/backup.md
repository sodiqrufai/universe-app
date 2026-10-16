# Backing up UniVerse before a test (non-technical guide)

Supabase's **free plan has no point-in-time backups**, so one mistake (a bad migration, a deleted table) can lose everything. Take a backup **before every test day and before every `supabase db push`**. It takes about 3 minutes.

There are two parts: the **database** (accounts, posts, messages...) and the **files** (profile photos, ID photos, post images).

## Part 1: Database (the important one)

You need **Docker Desktop** running (the Supabase tool uses it to run the dump) and the Supabase CLI you already use for `supabase db push`.

1. Get your connection string: Supabase dashboard -> your project -> **Connect** (top bar) -> **Session pooler** -> copy the URI. Replace `[YOUR-PASSWORD]` with your database password (Project Settings -> Database -> reset password if you've forgotten it).
2. Easiest: run the script from the repo (PowerShell, in `universe_backend`):

   ```powershell
   .\scripts\backup.ps1 -DbUrl "postgresql://postgres.xxxx:YOUR-PASSWORD@aws-0-xx.pooler.supabase.com:5432/postgres"
   ```

   It creates a dated folder `backups\2026-10-16_1430\` containing `schema.sql` and `data.sql`.
3. Check both files exist and are not empty (data.sql should be at least a few KB).
4. **Copy the folder somewhere safe that is not this computer only** (Google Drive, an external drive). Do **not** commit it to GitHub: it contains your students' data. The `backups/` folder is already in `.gitignore`.

Manual version of the same thing:

```powershell
supabase db dump --db-url "<URI>" -f backups\schema.sql
supabase db dump --db-url "<URI>" -f backups\data.sql --data-only --use-copy
```

(If a flag is rejected, run `supabase db dump --help`; the tool changes over time.)

## Part 2: Files (photos, ID documents)

The dump does **not** include uploaded files. Buckets: `avatars`, `post-media`, `story-media`, `listing-images`, `service-images`, `event-covers`, `announcement-images`, `resources`, `verification-docs`, `chat-attachments`, `chat-voice-notes`.

- For the test, the only files you can't recreate are **verification-docs** (ID photos) and the other user uploads. In the dashboard: **Storage** -> open a bucket -> select files -> Download. Do this for any bucket with files you care about.
- Treat `verification-docs` as private. Never share it or upload it anywhere public.

## How to restore (if something goes wrong)

Restoring overwrites data, so ask for help before doing it on the live project. In outline: create a fresh Supabase project, run `schema.sql` then `data.sql` in the SQL editor (or with `psql`), point the backend's `SUPABASE_URL` and keys on Render at the new project, and re-upload files.

## Routine

- Before each test day: backup, then check Render shows **Live**.
- After each test day: backup again (this contains the testers' real data, so handle it carefully).
- Keep the last 5 backups, delete older ones.
