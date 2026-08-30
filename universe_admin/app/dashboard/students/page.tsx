'use client';

import { useEffect, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';

type Student = {
  id: string;
  full_name: string;
  username: string;
  avatar_url: string | null;
  is_verified: boolean;
  is_suspended: boolean;
  role: string;
  universities: { name: string } | null;
};

export default function StudentsPage() {
  const [students, setStudents] = useState<Student[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | 'verified' | 'unverified' | 'suspended'>('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmTarget, setConfirmTarget] = useState<Student | null>(null);
  const pageSize = 25;

  useEffect(() => {
    fetchStudents();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, filter]);

  const fetchStudents = async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ page: String(page), pageSize: String(pageSize) });
      if (search.trim()) params.set('search', search.trim());
      if (filter !== 'all') params.set('filter', filter);
      const data = await adminApi.get(`/admin/students?${params}`);
      if (data.success) {
        setStudents(data.students);
        setTotal(data.total);
      } else {
        setError(data.error || 'Failed to load students');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  };

  const handleSuspendToggle = async (student: Student) => {
    try {
      const data = await adminApi.patch(`/admin/students/${student.id}/suspend`, {
        confirm: true,
        suspended: !student.is_suspended,
      });
      if (data.success) {
        setConfirmTarget(null);
        fetchStudents();
      } else {
        setError(data.error || 'Could not update student');
      }
    } catch {
      setError('Could not update student');
    }
  };

  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-foreground mb-1">Students</h1>
      <p className="text-text-secondary mb-6">{total} student{total === 1 ? '' : 's'} on the platform.</p>

      <div className="flex gap-3 mb-4 flex-wrap">
        <input
          type="text"
          placeholder="Search by name or username..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && (setPage(1), fetchStudents())}
          className="border border-border rounded-lg px-4 py-2 flex-1 min-w-[240px] focus:outline-none focus:ring-2 focus:ring-primary"
        />
        <select
          value={filter}
          onChange={(e) => {
            setFilter(e.target.value as typeof filter);
            setPage(1);
          }}
          className="border border-border rounded-lg px-4 py-2 bg-surface"
        >
          <option value="all">All</option>
          <option value="verified">Verified</option>
          <option value="unverified">Unverified</option>
          <option value="suspended">Suspended</option>
        </select>
        <button
          onClick={() => {
            setPage(1);
            fetchStudents();
          }}
          className="bg-primary text-white rounded-lg px-5 py-2 font-medium hover:bg-primary-dark transition"
        >
          Search
        </button>
      </div>

      {loading && <p className="text-text-secondary">Loading...</p>}
      {error && (
        <div className="bg-error/10 text-error rounded-lg px-4 py-3 mb-4 flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchStudents} className="font-semibold underline">
            Retry
          </button>
        </div>
      )}

      {!loading && !error && (
        <>
          <div className="bg-surface border border-border rounded-2xl overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-light-purple/40 text-text-secondary text-left">
                <tr>
                  <th className="px-4 py-3 font-medium">Name</th>
                  <th className="px-4 py-3 font-medium">University</th>
                  <th className="px-4 py-3 font-medium">Status</th>
                  <th className="px-4 py-3 font-medium">Role</th>
                  <th className="px-4 py-3 font-medium text-right">Action</th>
                </tr>
              </thead>
              <tbody>
                {students.map((s) => (
                  <tr key={s.id} className="border-t border-border">
                    <td className="px-4 py-3">
                      <p className="font-medium text-foreground">{s.full_name}</p>
                      <p className="text-text-muted text-xs">@{s.username}</p>
                    </td>
                    <td className="px-4 py-3 text-text-secondary">{s.universities?.name ?? '—'}</td>
                    <td className="px-4 py-3">
                      {s.is_suspended ? (
                        <span className="text-xs bg-error/10 text-error px-2 py-1 rounded-full font-medium">
                          Suspended
                        </span>
                      ) : s.is_verified ? (
                        <span className="text-xs bg-success/10 text-success px-2 py-1 rounded-full font-medium">
                          Verified
                        </span>
                      ) : (
                        <span className="text-xs bg-warning/10 text-warning px-2 py-1 rounded-full font-medium">
                          Unverified
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-text-secondary capitalize">{s.role}</td>
                    <td className="px-4 py-3 text-right">
                      <button
                        onClick={() => setConfirmTarget(s)}
                        className={`text-xs font-semibold px-3 py-1.5 rounded-lg transition ${
                          s.is_suspended
                            ? 'bg-success/10 text-success hover:bg-success/20'
                            : 'bg-error/10 text-error hover:bg-error/20'
                        }`}
                      >
                        {s.is_suspended ? 'Unsuspend' : 'Suspend'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="flex items-center justify-between mt-4">
            <p className="text-sm text-text-secondary">
              Page {page} of {totalPages}
            </p>
            <div className="flex gap-2">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
                className="px-3 py-1.5 rounded-lg border border-border text-sm disabled:opacity-40"
              >
                Previous
              </button>
              <button
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                disabled={page >= totalPages}
                className="px-3 py-1.5 rounded-lg border border-border text-sm disabled:opacity-40"
              >
                Next
              </button>
            </div>
          </div>
        </>
      )}

      {confirmTarget && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-surface rounded-2xl p-6 max-w-sm w-full">
            <h2 className="text-lg font-bold text-foreground mb-2">
              {confirmTarget.is_suspended ? 'Unsuspend' : 'Suspend'} {confirmTarget.full_name}?
            </h2>
            <p className="text-text-secondary text-sm mb-5">
              {confirmTarget.is_suspended
                ? 'This restores their ability to post, comment, and react.'
                : 'This blocks them from posting, commenting, or reacting until unsuspended.'}
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setConfirmTarget(null)}
                className="flex-1 bg-light-purple text-foreground rounded-lg py-2 font-semibold"
              >
                Cancel
              </button>
              <button
                onClick={() => handleSuspendToggle(confirmTarget)}
                className="flex-1 bg-error text-white rounded-lg py-2 font-semibold hover:opacity-90"
              >
                Confirm
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
