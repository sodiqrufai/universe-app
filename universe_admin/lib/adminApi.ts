import { API_BASE_URL } from './apiConfig';

export class AdminApiError extends Error {
  restricted: boolean;
  constructor(message: string, restricted = false) {
    super(message);
    this.restricted = restricted;
  }
}

/**
 * Shared authenticated fetch helper for the admin panel. Attaches the
 * stored admin token, normalizes NestJS's default exception shape
 * ({statusCode, message, error: "Forbidden"}) into a real error
 * message (same fix applied on the mobile side's ApiService — without
 * it, a restricted/permission error just shows the word "Forbidden"),
 * and redirects to /login on a 401 rather than leaving the page stuck
 * on a silent failure.
 */
async function request(
  path: string,
  options: { method?: string; body?: unknown } = {},
): Promise<any> {
  const token = typeof window !== 'undefined' ? localStorage.getItem('admin_token') : null;
  if (!token && typeof window !== 'undefined') {
    window.location.href = '/login';
    throw new AdminApiError('Not signed in');
  }

  const res = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method ?? 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  if (res.status === 401 && typeof window !== 'undefined') {
    localStorage.removeItem('admin_token');
    window.location.href = '/login';
    throw new AdminApiError('Session expired');
  }

  let data: any;
  try {
    data = await res.json();
  } catch {
    throw new AdminApiError('Unexpected response from server');
  }

  if (data.success !== true && !data.error && data.message) {
    data.error = Array.isArray(data.message) ? data.message.join(', ') : String(data.message);
  }
  if (res.status === 403) {
    data.restricted = true;
  }
  return data;
}

export const adminApi = {
  get: (path: string) => request(path),
  post: (path: string, body: unknown = {}) => request(path, { method: 'POST', body }),
  patch: (path: string, body: unknown = {}) => request(path, { method: 'PATCH', body }),
  delete: (path: string) => request(path, { method: 'DELETE' }),
};
