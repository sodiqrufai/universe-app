'use client';

import { useEffect, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';

type Report = {
  id: string;
  target_type: string;
  target_id: string;
  reason: string;
  status: string;
  created_at: string;
  reported_user_id: string | null;
  reporter: { full_name: string; username: string } | null;
};

// Maps a report's target_type to the admin removal endpoint that
// applies to it. 'chat' has no matching endpoint by design — a
// reported conversation isn't a single removable item on this
// backend, so it's resolved (warned/dismissed) rather than removed.
const REMOVE_ENDPOINT: Record<string, string> = {
  post: '/admin/posts',
  anonymous_post: '/admin/anonymous',
  listing: '/admin/listings',
  service: '/admin/services',
  event: '/admin/events',
};

const TYPE_LABELS: Record<string, string> = {
  post: 'Post',
  anonymous_post: 'Anonymous Post',
  listing: 'Marketplace Listing',
  service: 'Service',
  event: 'Event',
  chat: 'Chat',
};

export default function ReportsPage() {
  const [reports, setReports] = useState<Report[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [typeFilter, setTypeFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('pending');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionTarget, setActionTarget] = useState<{ report: Report; action: 'remove' | 'resolve' | 'dismiss' } | null>(null);
  const [reasonInput, setReasonInput] = useState('');
  const [revealed, setRevealed] = useState<Record<string, { full_name: string; username: string }>>({});
  const [revealReasonFor, setRevealReasonFor] = useState<Report | null>(null);
  const pageSize = 25;

  useEffect(() => {
    fetchReports();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, typeFilter, statusFilter]);

  const fetchReports = async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ page: String(page), pageSize: String(pageSize) });
      if (typeFilter !== 'all') params.set('type', typeFilter);
      if (statusFilter !== 'all') params.set('status', statusFilter);
      const data = await adminApi.get(`/admin/reports?${params}`);
      if (data.success) {
        setReports(data.reports);
        setTotal(data.total);
      } else {
        setError(data.error || 'Failed to load reports');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  };

  const handleRemove = async () => {
    if (!actionTarget || !reasonInput.trim()) return;
    const endpoint = REMOVE_ENDPOINT[actionTarget.report.target_type];
    if (!endpoint) return;
    try {
      const data = await adminApi.patch(`${endpoint}/${actionTarget.report.target_id}/remove`, {
        confirm: true,
        reason: reasonInput.trim(),
      });
      if (data.success) {
        await adminApi.patch(`/admin/reports/${actionTarget.report.id}`, {
          status: 'reviewed',
          resolutionNote: `Content removed: ${reasonInput.trim()}`,
        });
        setActionTarget(null);
        setReasonInput('');
        fetchReports();
      } else {
        setError(data.error || 'Could not remove content');
      }
    } catch {
      setError('Could not remove content');
    }
  };

  const handleResolve = async (status: 'reviewed' | 'dismissed') => {
    if (!actionTarget) return;
    try {
      const data = await adminApi.patch(`/admin/reports/${actionTarget.report.id}`, {
        status,
        resolutionNote: reasonInput.trim() || undefined,
      });
      if (data.success) {
        setActionTarget(null);
        setReasonInput('');
        fetchReports();
      } else {
        setError(data.error || 'Could not resolve report');
      }
    } catch {
      setError('Could not resolve report');
    }
  };

  const handleReveal = async () => {
    if (!revealReasonFor || !reasonInput.trim()) return;
    try {
      const data = await adminApi.post(`/admin/reports/${revealReasonFor.id}/reveal-identity`, {
        reason: reasonInput.trim(),
      });
      if (data.success) {
        setRevealed((prev) => ({ ...prev, [revealReasonFor.id]: data.identity }));
        setRevealReasonFor(null);
        setReasonInput('');
      } else {
        setError(data.error || 'Could not reveal identity');
      }
    } catch {
      setError('Could not reveal identity — this requires super_admin access.');
    }
  };

  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-foreground mb-1">Reports & Moderation</h1>
      <p className="text-text-secondary mb-6">
        Content moderation happens through reports — there&apos;s no general content browser, so this
        is the entry point for removing anything.
      </p>

      <div className="flex gap-3 mb-4 flex-wrap">
        <select
          value={typeFilter}
          onChange={(e) => {
            setTypeFilter(e.target.value);
            setPage(1);
          }}
          className="border border-border rounded-lg px-4 py-2 bg-surface"
        >
          <option value="all">All types</option>
          {Object.entries(TYPE_LABELS).map(([k, v]) => (
            <option key={k} value={k}>
              {v}
            </option>
          ))}
        </select>
        <select
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value);
            setPage(1);
          }}
          className="border border-border rounded-lg px-4 py-2 bg-surface"
        >
          <option value="pending">Pending</option>
          <option value="reviewed">Reviewed</option>
          <option value="dismissed">Dismissed</option>
          <option value="all">All statuses</option>
        </select>
      </div>

      {loading && <p className="text-text-secondary">Loading...</p>}
      {error && (
        <div className="bg-error/10 text-error rounded-lg px-4 py-3 mb-4 flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchReports} className="font-semibold underline">
            Retry
          </button>
        </div>
      )}

      {!loading && !error && reports.length === 0 && (
        <p className="text-text-secondary">No reports match these filters.</p>
      )}

      <div className="space-y-3">
        {reports.map((r) => (
          <div key={r.id} className="bg-surface border border-border rounded-2xl p-5">
            <div className="flex items-start justify-between gap-4">
              <div>
                <span className="text-xs bg-light-purple text-primary px-2 py-1 rounded-full font-medium">
                  {TYPE_LABELS[r.target_type] ?? r.target_type}
                </span>
                <p className="mt-2 text-foreground">{r.reason}</p>
                <p className="text-xs text-text-muted mt-1">
                  Reported by {r.reporter?.full_name ?? 'Unknown'} (@{r.reporter?.username ?? '—'}) •{' '}
                  {new Date(r.created_at).toLocaleDateString()}
                </p>
                {r.target_type === 'anonymous_post' && (
                  <div className="mt-2">
                    {revealed[r.id] ? (
                      <p className="text-xs text-error font-medium">
                        Revealed identity: {revealed[r.id].full_name} (@{revealed[r.id].username})
                      </p>
                    ) : (
                      <button
                        onClick={() => setRevealReasonFor(r)}
                        className="text-xs text-error underline font-medium"
                      >
                        Reveal identity (super_admin, logged)
                      </button>
                    )}
                  </div>
                )}
              </div>
              <span
                className={`text-xs px-2 py-1 rounded-full font-medium shrink-0 ${
                  r.status === 'pending'
                    ? 'bg-warning/10 text-warning'
                    : r.status === 'dismissed'
                    ? 'bg-text-muted/10 text-text-muted'
                    : 'bg-success/10 text-success'
                }`}
              >
                {r.status}
              </span>
            </div>

            {r.status === 'pending' && (
              <div className="flex gap-2 mt-4">
                {REMOVE_ENDPOINT[r.target_type] && (
                  <button
                    onClick={() => setActionTarget({ report: r, action: 'remove' })}
                    className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-error/10 text-error hover:bg-error/20"
                  >
                    Remove Content
                  </button>
                )}
                <button
                  onClick={() => setActionTarget({ report: r, action: 'resolve' })}
                  className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-success/10 text-success hover:bg-success/20"
                >
                  Mark Reviewed
                </button>
                <button
                  onClick={() => setActionTarget({ report: r, action: 'dismiss' })}
                  className="text-xs font-semibold px-3 py-1.5 rounded-lg bg-light-purple text-text-secondary hover:opacity-80"
                >
                  Dismiss
                </button>
              </div>
            )}
          </div>
        ))}
      </div>

      {!loading && !error && reports.length > 0 && (
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
      )}

      {actionTarget && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-surface rounded-2xl p-6 max-w-md w-full">
            <h2 className="text-lg font-bold text-foreground mb-2">
              {actionTarget.action === 'remove' && 'Remove this content?'}
              {actionTarget.action === 'resolve' && 'Mark this report as reviewed?'}
              {actionTarget.action === 'dismiss' && 'Dismiss this report?'}
            </h2>
            {actionTarget.action === 'remove' && (
              <p className="text-text-secondary text-sm mb-3">
                This removes the content and notifies its author with your reason.
              </p>
            )}
            <textarea
              placeholder={actionTarget.action === 'remove' ? 'Reason (required, shown to the author)' : 'Note (optional)'}
              value={reasonInput}
              onChange={(e) => setReasonInput(e.target.value)}
              className="w-full border border-border rounded-lg px-4 py-2 mb-4 focus:outline-none focus:ring-2 focus:ring-primary"
              rows={3}
            />
            <div className="flex gap-3">
              <button
                onClick={() => {
                  setActionTarget(null);
                  setReasonInput('');
                }}
                className="flex-1 bg-light-purple text-foreground rounded-lg py-2 font-semibold"
              >
                Cancel
              </button>
              <button
                onClick={() =>
                  actionTarget.action === 'remove' ? handleRemove() : handleResolve(actionTarget.action === 'dismiss' ? 'dismissed' : 'reviewed')
                }
                disabled={actionTarget.action === 'remove' && !reasonInput.trim()}
                className="flex-1 bg-error text-white rounded-lg py-2 font-semibold hover:opacity-90 disabled:opacity-40"
              >
                Confirm
              </button>
            </div>
          </div>
        </div>
      )}

      {revealReasonFor && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-surface rounded-2xl p-6 max-w-md w-full">
            <h2 className="text-lg font-bold text-foreground mb-2">Reveal anonymous identity</h2>
            <p className="text-text-secondary text-sm mb-3">
              This is logged with your reason and is only for exceptional cases (e.g. safety threats).
            </p>
            <textarea
              placeholder="Reason (required)"
              value={reasonInput}
              onChange={(e) => setReasonInput(e.target.value)}
              className="w-full border border-border rounded-lg px-4 py-2 mb-4 focus:outline-none focus:ring-2 focus:ring-error"
              rows={3}
            />
            <div className="flex gap-3">
              <button
                onClick={() => {
                  setRevealReasonFor(null);
                  setReasonInput('');
                }}
                className="flex-1 bg-light-purple text-foreground rounded-lg py-2 font-semibold"
              >
                Cancel
              </button>
              <button
                onClick={handleReveal}
                disabled={!reasonInput.trim()}
                className="flex-1 bg-error text-white rounded-lg py-2 font-semibold hover:opacity-90 disabled:opacity-40"
              >
                Reveal
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
