'use client';

import { useCallback, useEffect, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';
import { formatDateTime } from '../../../lib/format';
import Pager from '../../../components/Pager';

// Shape per the shared contract: GET /admin/waitlist-signups
//   -> {success, items, total, page, pageSize}
// Item fields verified against admin.controller.ts getWaitlistSignups():
// id, email, created_at, university_id, universities {name, short_name}.
type Signup = {
  id: string;
  email: string;
  university_id?: string;
  created_at: string;
  universities?: { name: string; short_name?: string | null } | null;
};

type University = { id: string; name: string };

const PAGE_SIZE = 25;

export default function WaitlistSignupsPage() {
  const [items, setItems] = useState<Signup[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [universityId, setUniversityId] = useState('');
  const [universities, setUniversities] = useState<University[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const data = await adminApi.get('/admin/universities');
        if (data.success) setUniversities(data.universities);
      } catch {
        // The filter just stays empty; the list itself still works.
      }
    })();
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ page: String(page), pageSize: String(PAGE_SIZE) });
      if (universityId) params.set('universityId', universityId);
      const data = await adminApi.get(`/admin/waitlist-signups?${params}`);
      if (data.success) {
        setItems(data.items);
        setTotal(data.total);
      } else {
        setError(data.error || 'Failed to load waitlist signups');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  }, [page, universityId]);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-foreground mb-1">Waitlist Signups</h1>
      <p className="text-text-secondary mb-6">
        {total} signup{total === 1 ? '' : 's'} from the landing page, for universities that are not
        live yet.
      </p>

      <div className="flex gap-3 mb-4 flex-wrap">
        <select
          value={universityId}
          onChange={(e) => {
            setUniversityId(e.target.value);
            setPage(1);
          }}
          className="border border-border rounded-lg px-4 py-2 bg-surface min-w-[240px]"
        >
          <option value="">All universities</option>
          {universities.map((u) => (
            <option key={u.id} value={u.id}>
              {u.name}
            </option>
          ))}
        </select>
      </div>

      {loading && <p className="text-text-secondary">Loading...</p>}
      {error && (
        <div className="bg-error/10 text-error rounded-lg px-4 py-3 mb-4 flex items-center justify-between">
          <span>{error}</span>
          <button onClick={load} className="font-semibold underline">
            Retry
          </button>
        </div>
      )}

      {!loading && !error && items.length === 0 && (
        <p className="text-text-secondary">No waitlist signups yet.</p>
      )}

      {!loading && !error && items.length > 0 && (
        <>
          <div className="bg-surface border border-border rounded-2xl overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-light-purple/40 text-text-secondary text-left">
                <tr>
                  <th className="px-4 py-3 font-medium">Email</th>
                  <th className="px-4 py-3 font-medium">University</th>
                  <th className="px-4 py-3 font-medium">Signed up</th>
                </tr>
              </thead>
              <tbody>
                {items.map((s) => (
                  <tr key={s.id} className="border-t border-border">
                    <td className="px-4 py-3 text-foreground">{s.email}</td>
                    <td className="px-4 py-3 text-text-secondary">
                      {s.universities?.name ?? '—'}
                    </td>
                    <td className="px-4 py-3 text-text-secondary">{formatDateTime(s.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <Pager page={page} pageSize={PAGE_SIZE} total={total} onChange={setPage} />
        </>
      )}
    </div>
  );
}
