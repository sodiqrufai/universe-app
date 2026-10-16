// Must be imported FIRST in main.ts so Sentry can hook everything that loads after it.
// Completely inert unless SENTRY_DSN is set in the environment (Render → Environment).
import * as Sentry from '@sentry/node';

if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.SENTRY_ENV ?? process.env.NODE_ENV ?? 'production',
    tracesSampleRate: 0.1,
    // Sentry's default is NOT to send PII (headers/cookies/bodies); we deliberately leave it that way.
  });
}
