# UniVerse Founder Runbook

For you, not an engineer. Each section says what to do and why. Screens at Resend, Brevo, Supabase,
UptimeRobot, Sentry and Render change their labels now and then, so if a menu name differs slightly,
look for the closest one. **Free-tier limits change, so check each service's pricing page before relying on a number here.**

## Do this first: back up before every test

Before each usability session (and before any big change):

1. **Database and files**: follow `universe_backend/scripts/backup.md` (the script `universe_backend/scripts/backup.ps1` does the database part in one command; it also lists which storage buckets to download by hand, especially `verification-docs`). Supabase's free plan has no point-in-time backups, so this is your only safety net. Keep the backup folder private (it holds students' data) and never put it on GitHub.
2. **GitHub**: confirm everything is pushed (the repo is itself your code backup).
3. **Keep a copy of your secrets** (see section 6) in a password manager, not in chat or email.


---

## 1. Real email sending (custom SMTP)

**Why:** Supabase's built-in email sender is only for testing and allows very few emails per hour, so
sign-up confirmation and password-reset emails will fail once a group of testers sign up.

Pick **one**: Resend or Brevo. You need a domain you own (e.g. `universe.ng`). Emails sent from a
Gmail address will land in spam or be blocked, so use a domain address like `no-reply@yourdomain`.

### Option A: Resend

1. Create an account at resend.com → **Domains → Add Domain** → enter your domain (or a subdomain like `mail.yourdomain`).
2. Resend shows DNS records (usually 1 TXT for SPF, 1 TXT/CNAME for DKIM, and sometimes an MX). Copy each exactly.
3. Add them where you manage the domain (the registrar, e.g. Namecheap/GoDaddy, or Cloudflare):
   **DNS settings → Add record**, choosing the same **Type**, **Name/Host** and **Value** Resend shows.
   If your DNS host auto-appends your domain to the Name, enter only the part before it.
4. Back in Resend, click **Verify**. It can take minutes to a few hours. Wait for **Verified**.
5. **API Keys → Create API Key** (permission: Sending access). Copy it once.
6. Supabase: **Authentication → Emails → SMTP Settings** (older: **Project Settings → Authentication → SMTP**):
   - Enable custom SMTP
   - Sender email: `no-reply@yourdomain` (must be on the verified domain)
   - Sender name: `UniVerse`
   - Host: `smtp.resend.com`
   - Port: `465` (or `587` if your project asks for it)
   - Username: `resend`
   - Password: the API key from step 5
7. Save, then sign up with a test address to confirm the email arrives.

### Option B: Brevo

1. Create an account at brevo.com → **Senders, Domains & Dedicated IPs → Domains → Add a domain** and verify it.
2. Add the DNS records Brevo shows (Brevo code TXT, DKIM, and DMARC if shown) the same way as above, then click **Authenticate**.
3. **SMTP & API → SMTP** tab → note your SMTP login, and **Generate a new SMTP key**; copy it.
4. Supabase SMTP settings:
   - Sender email: an address on your verified domain; Sender name: `UniVerse`
   - Host: `smtp-relay.brevo.com`
   - Port: `587`
   - Username: your Brevo SMTP login (shown on that page)
   - Password: the SMTP key (not your Brevo account password)
5. Save and test.

**Check:** the test email arrives in the inbox (not spam) and the sender shows "UniVerse".
After this, also set **Authentication → Rate Limits** in Supabase to a higher email limit if the dashboard allows, since custom SMTP lifts the built-in cap.

Then paste in the branded email designs from `email_templates/README.md`.

---

## 2. Know when the backend is down (UptimeRobot)

1. Sign up at uptimerobot.com (free plan).
2. **+ New monitor** → type **HTTP(s)**.
3. Name: `UniVerse API health`. URL: `https://universe-app-w4cc.onrender.com/health`.
4. Monitoring interval: **5 minutes**.
5. Under **Alert contacts**, tick your email (add your WhatsApp/Telegram if offered). Save.
6. Add a second monitor, `UniVerse database check`, URL `https://universe-app-w4cc.onrender.com/universities`, 5 minutes.

Why two: `/health` proves the server is up; `/universities` also reads the database, which helps keep Supabase from pausing (section 4).

Bonus: pinging every 5 minutes also keeps Render's free server from falling asleep, which removes the
"first load takes a minute" delay. Check Render's current free-hours allowance; constant pinging uses
the monthly hours quickly.

**Note:** `/health` is live in the backend code (it returns `{status: "ok", time}` and deliberately doesn't touch the database). It only answers once the latest backend is deployed on Render; until then the monitor will show Down.

---

## 3. Catch crashes (Sentry)

1. Sign up at sentry.io (free plan), create an organisation.
2. Create **two projects**:
   - Platform **Node.js** (or NestJS), name `universe-backend`
   - Platform **Flutter**, name `universe-mobile`
3. Each project shows a **DSN**, a long address like `https://abc123@o123.ingest.sentry.io/456`. Find it again under **Settings → Projects → (project) → Client Keys (DSN)**.
4. Where each DSN goes:

| DSN for | Where | How |
|---|---|---|
| Backend | Render → your service → **Environment** | add `SENTRY_DSN` = the backend DSN |
| Mobile / web app | Build command | `--dart-define=SENTRY_DSN=the-mobile-DSN` (ask your engineer to add it to the build command or `build_site.ps1`) |

5. In Sentry: **Alerts → Create Alert** → "issues" → email you on a new issue.
6. A DSN isn't a password but don't post it publicly either.

**Check:** the engineer triggers a test error; it shows up in Sentry within a minute.
The backend code is ready and starts reporting once `SENTRY_DSN` is set. I did not see mobile Sentry code in what I read, so confirm with your engineer that the app side exists before expecting mobile errors.

---

## 4. Supabase free-tier limits and keep-alive

- **Pausing:** free projects are paused after about a week with no activity. Paused = the app and the admin portal stop working. You may have seen this when you could not find your project: check the dashboard for a "paused" banner and press **Restore project**.
- The `/universities` monitor in section 2 touches the database every 5 minutes, which counts as activity. Do not rely on it alone; open the dashboard before each test week.
- Check these current limits on supabase.com/pricing: database size, file storage, monthly active users, bandwidth, and emails per hour (built-in sender).
- **Where to check usage:** Dashboard → **Settings → Usage** (or **Organization → Usage**). Look weekly during testing.
- Uploads: the app now rejects over-size files (image 8 MB, video 50 MB, audio 5 MB, documents 10 MB, ID photo 8 MB). Videos eat free storage fastest, so watch **Storage**.
- If you pass the limits, upgrading to the paid plan is the fix; deleting test data helps in the short term.

---

## 5. Render (backend) settings

Render → your service → **Environment**. Set (names must match exactly):

| Name | What | Notes |
|---|---|---|
| `SUPABASE_URL` | Supabase → Settings → API → Project URL | already set |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Settings → API → service_role | **secret**, never in the app or GitHub |
| `SUPABASE_ANON_KEY` | Supabase → Settings → API → anon | already set |
| `PUBLIC_BASE_URL` | `https://universe-app-w4cc.onrender.com` | used to build email links |
| `EMAIL_CONFIRM_REDIRECT_URL` | where the "confirm email" link lands | optional; has a default |
| `PASSWORD_RESET_REDIRECT_URL` | where the "reset password" link lands | optional; has a default |
| `SENTRY_DSN` | from section 3 | optional; nothing is sent while empty |
| `ALLOWED_ORIGINS` | comma-separated list, e.g. `https://your-site.netlify.app,https://your-admin.vercel.app` | the websites allowed to call the API; no trailing slashes |

After changing variables Render restarts the service. Wait for "Live" and open `/health`.

All of these names are read by the backend code today (`SENTRY_DSN` in `instrument.ts`, `ALLOWED_ORIGINS` in `main.ts`). `SENTRY_DSN` is inert when empty. If `ALLOWED_ORIGINS` is empty, the API stays open to every website and logs a warning, so set it before public launch; local addresses (localhost) are always allowed. Add every site that calls the API: the landing/web-app address and the admin portal address.

Also set in Supabase **Authentication → URL Configuration**: Site URL = your landing address (not localhost).

---

## 6. Secrets checklist

Keep in a password manager: Supabase service_role key, Resend/Brevo key, Sentry DSNs, UptimeRobot login, Render and GitHub logins. Never send the service_role key in WhatsApp or email. If one leaks, regenerate it in that service's dashboard and update Render.

---

## 7. Before each test session (10-minute checklist)

- [ ] Backup done (top of this file)
- [ ] Supabase project not paused
- [ ] `/health` shows `status: ok` in a browser
- [ ] Sign-up email arrives within a minute and opens a non-localhost link
- [ ] UptimeRobot monitors green
- [ ] Admin portal loads, and you can see test accounts under Students
- [ ] Test accounts ready (see `docs/usability/`)
