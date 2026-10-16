import { throttlerConfig, userIdFromAuthHeader } from './throttle';

const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = (payload: object) => `Bearer ${b64({ alg: 'none' })}.${b64(payload)}.sig`;
const UID = '11111111-1111-1111-1111-111111111111';

describe('userIdFromAuthHeader', () => {
  it('reads the user id from a bearer token', () => {
    expect(userIdFromAuthHeader(jwt({ sub: UID }))).toBe(UID);
  });
  it('returns null when there is no header or it is not a bearer token', () => {
    expect(userIdFromAuthHeader(undefined)).toBeNull();
    expect(userIdFromAuthHeader('Basic abc')).toBeNull();
  });
  it('returns null for malformed tokens', () => {
    expect(userIdFromAuthHeader('Bearer notajwt')).toBeNull();
    expect(userIdFromAuthHeader('Bearer a.b.c')).toBeNull();
  });
  it('rejects a sub that is not a UUID (cannot be used to craft odd bucket keys)', () => {
    expect(userIdFromAuthHeader(jwt({ sub: 'admin; drop table' }))).toBeNull();
    expect(userIdFromAuthHeader(jwt({ sub: 123 }))).toBeNull();
    expect(userIdFromAuthHeader(jwt({}))).toBeNull();
  });
});

describe('throttlerConfig', () => {
  const [byUser, byIp] = (throttlerConfig as any).throttlers;

  it('keeps the "default" name that existing @Throttle decorators override', () => {
    expect(byUser.name).toBe('default');
  });
  it('gives two users behind the same IP separate buckets', () => {
    const a = byUser.getTracker({ ip: '5.5.5.5', headers: { authorization: jwt({ sub: UID }) } });
    const b = byUser.getTracker({
      ip: '5.5.5.5',
      headers: { authorization: jwt({ sub: '22222222-2222-2222-2222-222222222222' }) },
    });
    expect(a).not.toBe(b);
  });
  it('falls back to the IP when logged out', () => {
    expect(byUser.getTracker({ ip: '5.5.5.5', headers: {} })).toBe('ip:5.5.5.5');
  });
  it('keeps a per-IP ceiling that ignores the token, so forged ids cannot dodge it', () => {
    const a = byIp.getTracker({ ip: '5.5.5.5', headers: { authorization: jwt({ sub: UID }) } });
    const b = byIp.getTracker({ ip: '5.5.5.5', headers: {} });
    expect(a).toBe(b);
    expect(byIp.limit).toBeGreaterThan(byUser.limit);
  });
  it('is generous enough for a chat that polls every 3 seconds (20/min) plus normal use', () => {
    expect(byUser.limit).toBeGreaterThanOrEqual(100);
  });
});
