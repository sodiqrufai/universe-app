'use client';

import { useCallback, useEffect, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';
import { formatDateTime } from '../../../lib/format';
import Pager from '../../../components/Pager';

type Category = 'bug' | 'idea' | 'other';

// Shape per the shared contract: GET /admin/feedback
//   -> {success, items, total, page, pageSize}
// POST /feedback accepts {message, category, screen?, appVersion?, platform?}.
// Item fields verified against admin.controller.ts getFeedback():
// id, user_id, message, category, screen, app_version, platform, status,
// created_at, and `author` ({id, full_name, username} or null).
// PATCH /admin/feedback/:id {status: 'new'|'reviewed'|'closed'} -> {success}.
type FeedbackStatus = 'new' | 'reviewed' | 'closed';
type FeedbackItem = {
  id: string;
  message: string;
  category: Category | string;
  screen?: string | null;
  app_version?: string | null;
  platform?: string | null;
  status?: FeedbackStatus | null;
  created_at: string;
  user_id?: string | null;
  author?: { full_name?: string; username?: string } | null;
};

const PAGE_SIZE = 25;

const STATUS_STYLE: Record<FeedbackStatus, string> = {
  new: 'bg-warning/15 text-warning',
  reviewed: 'bg-info/15 text-info',
  closed: 'bg-success/15 text-success',
};

const CATEGORY_STYLE: Record<string, string> = {
  bug: 'bg-error/15 text-error',
  idea: 'bg-success/15 text-success',
  other: 'bg-light-purple text-primary',
};

export default function FeedbackInboxPage() {
  const [items, setItems] = useState<FeedbackItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [category, setCategory] = useState<'all' | Category>('all');
  const [statusFilter, setStatusFilter] = useState<'all' | FeedbackStatus>('all');
  const [savingId, setSavingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ page: String(page), pageSize: String(PAGE_SIZE) });
      if (category !== 'all') params.set('category', category);
      if (statusFilter !== 'all') params.set('status', statusFilter);
      const data = await adminApi.get(`/admin/feedback?${params}`);
      if (data.success) {
        setItems(data.items);
        setTotal(data.total);
      } else {
        setError(data.error || 'Failed to load feedback');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  }, [page, category, statusFilter]);

  useEffect(() => {
    load();
  }, [load]);

  const changeStatus = async (item: FeedbackItem, status: FeedbackStatus) => {
    setSavingId(item.id);
    setActionError(null);
    try {
      const data = await adminApi.patch(`/admin/feedback/${item.id}`, { status });
      if (data.success) {
        await load();
      } else {
        setActionError(data.error || 'Could not update status');
      }
    } catch {
      setActionError('Could not update status');
    } finally {
      setSavingId(null);
    }
  };

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-foreground mb-1">Feedback Inbox</h1>
      <p className="text-text-secondary mb-6">
        {total} item{total === 1 ? '' : 's'} sent from inside the app.
      </p>

      <div className="flex gap-3 mb-4 flex-wrap">
        <select
          value={category}
          onChange={(e) => {
            setCategory(e.target.value as typeof category);
            setPage(1);
          }}
          className="border border-border rounded-lg px-4 py-2 bg-surface"
        >
          <option value="all">All categories</option>
          <option value="bug">Bugs</option>
          <option value="idea">Ideas</option>
          <option value="other">Other</option>
        </select>
        <select
          value={statusFilter}
          onChange={(e) => {
            setStatusFilter(e.target.value as typeof statusFilter);
            setPage(1);
          }}
          className="border border-border rounded-lg px-4 py-2 bg-surface"
        >
          <option value="all">All statuses</option>
          <option value="new">New</option>
          <option value="reviewed">Reviewed</option>
          <option value="closed">Closed</option>
        </select>
      </div>
      {actionError && (
        <div className="bg-error/10 text-error rounded-lg px-4 py-3 mb-4">{actionError}</div>
      )}

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
        <p className="text-text-secondary">No feedback yet.</p>
      )}

      {!loading && !error && (
        <div className="space-y-3">
          {items.map((f) => {
            const version = f.app_version;
            const who = f.author?.full_name || f.author?.username;
            const status: FeedbackStatus = f.status ?? 'new';
            const meta = [f.screen && `Screen: ${f.screen}`, version && `v${version}`, f.platform]
              .filter(Boolean)
              .join(' · ');
            return (
              <div key={f.id} className="bg-surface border border-border p-4 rounded-xl">
                <div className="flex justify-between items-start gap-3 mb-2">
                  <span
                    className={`text-xs px-3 py-1 rounded-full font-medium capitalize ${
                      CATEGORY_STYLE[f.category] ?? CATEGORY_STYLE.other
                    }`}
                  >
                    {f.category}
                  </span>
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-text-muted mr-1">{formatDateTime(f.created_at)}</span>
                    <span
                      className={`text-xs px-3 py-1 rounded-full font-medium capitalize ${STATUS_STYLE[status]}`}
                    >
                      {status}
                    </span>
                    <select
                      value={status}
                      disabled={savingId === f.id}
                      onChange={(e) => changeStatus(f, e.target.value as FeedbackStatus)}
                      className="border border-border rounded-lg px-2 py-1 text-sm bg-surface disabled:opacity-50"
                      aria-label="Change status"
                    >
                      <option value="new">New</option>
                      <option value="reviewed">Reviewed</option>
                      <option value="closed">Closed</option>
                    </select>
                  </div>
                </div>
                <p className="text-sm text-foreground whitespace-pre-wrap">{f.message}</p>
                <p className="text-xs text-text-muted mt-3">
                  {who ? `From ${who}` : 'Anonymous / signed-out'}
                  {meta ? ` · ${meta}` : ''}
                </p>
              </div>
            );
          })}
        </div>
      )}

      {!loading && !error && total > PAGE_SIZE && (
        <Pager page={page} pageSize={PAGE_SIZE} total={total} onChange={setPage} />
      )}
    </div>
  );
}
