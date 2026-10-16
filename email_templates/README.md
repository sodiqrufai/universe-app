# UniVerse email templates

Three branded emails for Supabase Auth, in UniVerse purple (#4F2CCF / #2D1B8C).

| File | Supabase template name | Suggested subject |
|---|---|---|
| `confirm_signup.html` | Confirm signup | Confirm your UniVerse account |
| `reset_password.html` | Reset password | Reset your UniVerse password |
| `change_email.html` | Change email address | Confirm your new UniVerse email |

## How to paste them in (about 5 minutes)

1. Open your project at https://supabase.com/dashboard.
2. Go to **Authentication** → **Emails** (older dashboards: **Authentication → Email Templates**).
3. Click the template (e.g. **Confirm signup**).
4. Replace the **Subject** with the suggested subject above.
5. Open the matching `.html` file here, copy **everything**, and paste it into the **Message body** box, replacing what is there.
6. Click **Save**. Repeat for the other two.

Do not edit anything in double curly braces, such as `{{ .ConfirmationURL }}`. Supabase fills those in.

## Before you test: fix the Site URL

The logo in each email loads from `{{ .SiteURL }}/assets/logo.png`, and the confirm links
also depend on your URL settings. In Supabase go to **Authentication → URL Configuration** and set:

- **Site URL**: your real landing page address, e.g. `https://your-site.netlify.app`
  (no trailing slash). It must be the address where `/assets/logo.png` opens in a browser.
- **Redirect URLs**: add the same address with `/**` on the end, plus the backend address if the
  backend sends users back to it (e.g. `https://universe-app-w4cc.onrender.com/**`).

Do not leave it on `http://127.0.0.1:3000` (the default in `config.toml`). That is why
confirmation links were opening on localhost. The backend also reads the env vars
`PUBLIC_BASE_URL`, `EMAIL_CONFIRM_REDIRECT_URL` and `PASSWORD_RESET_REDIRECT_URL`; see the runbook.

## Testing

Sign up with a real address you own and check: the email arrives (check Spam), the logo shows,
and the button opens a page that is **not** localhost. Test the reset email the same way.

## Notes

- Email apps often hide images until you tap "show images". The purple header still shows without
  the logo.
- Supabase's built-in email sender is only meant for light testing and has a very low hourly limit.
  Set up custom SMTP first (runbook, section 1).
- These were checked as HTML and for the placeholder names, but not sent through real Gmail, Outlook
  or Yahoo inboxes.
