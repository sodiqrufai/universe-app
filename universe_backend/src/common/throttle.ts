import { ThrottlerModuleOptions } from '@nestjs/throttler';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Reads the user id (JWT `sub`) from a bearer token WITHOUT a network call. */
export function userIdFromAuthHeader(header?: string): string | null {
  if (!header?.startsWith('Bearer ')) return null;
  const parts = header.slice(7).split('.');
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    return typeof payload?.sub === 'string' && UUID.test(payload.sub) ? payload.sub : null;
  } catch {
    return null;
  }
}

/**
 * Two layers:
 *  - "default": per signed-in USER (falls back to IP when logged out). This is
 *    the limit routes override with @Throttle({ default: {...} }). Keyed per
 *    user so a whole campus behind one Wi-Fi/NAT address doesn't share a bucket.
 *  - "ipCeiling": a generous per-IP cap that exists only to stop abuse. The
 *    user id is read from an UNVERIFIED token, so an attacker could rotate fake
 *    ids to dodge "default"; this ceiling is what still bounds them.
 *
 * Needs `app.set('trust proxy', 1)` (see main.ts) so req.ip is the real client
 * and not Render's proxy.
 */
export const throttlerConfig: ThrottlerModuleOptions = {
  throttlers: [
    {
      name: 'default',
      ttl: 60_000,
      limit: 120,
      getTracker: (req: Record<string, any>) => {
        const uid = userIdFromAuthHeader(req.headers?.authorization);
        return uid ? `u:${uid}` : `ip:${req.ip}`;
      },
    },
    {
      name: 'ipCeiling',
      ttl: 60_000,
      limit: 1200,
      getTracker: (req: Record<string, any>) => `ip:${req.ip}`,
    },
  ],
};
