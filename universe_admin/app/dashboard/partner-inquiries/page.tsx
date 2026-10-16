'use client';

import { useCallback, useEffect, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';
import { formatDateTime } from '../../../lib/format';
import Pager from '../../../components/Pager';

type InquiryStatus = 'new' | 'contacted' | 'closed';

// Shape per the shared contract: GET /admin/partner-inquiries
//   -> {success, items, total, page, pageSize}
// Item fields verified against admin.controller.ts getPartnerInquiries():
// id, name, organization, email, message, status, created_at.
type Inquiry = {
  id: string;
  name: string;
  organization: string | null;
  email: string;
  message: string;
  created_at: string;
  status?: InquiryStatus | null;
};

const PAGE_SIZE = 25;

const STATUS_STYLE: Record<InquiryStatus, string> = {
  new: 'bg-warning/15 text-warning',
  contacted: 'bg-info/15 text-info',
  closed: 'bg-success/15 text-success',
};

export default function PartnerInquiriesPage() {
  const [items, setItems] = useState<Inquiry[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [filter, setFilter] = useState<'all' | InquiryStatus>('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [savingId, setSavingId] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ page: String(page), pageSize: String(PAGE_SIZE) });
      if (filter !== 'all') params.set('status', filter);
      const data = await adminApi.get(`/admin/partner-inquiries?${params}`);
      if (data.success) {
        setItems(data.items);
        setTotal(data.total);
      } else {
        setError(data.error || 'Failed to load partner inquiries');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  }, [page, filter]);

  useEffect(() => {
    load();
  }, [load]);

  const changeStatus = async (inquiry: Inquiry, status: InquiryStatus) => {
    setSavingId(inquiry.id);
    setActionError(null);
    try {
      const data = await adminApi.patch(`/admin/partner-inquiries/${inquiry.id}`, { status });
      if (data.success) {
        // Re-load so a filtered list drops the row that no longer matches.
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
      <h1 className="text-2xl font-bold text-foreground mb-1">Partner Inquiries</h1>
      <p className="text-text-secondary mb-6">
        {total} message{total === 1 ? '' : 's'} from the landing page contact form.
      </p>

      <div className="flex gap-3 mb-4 flex-wrap">
        <select
          value={filter}
          onChange={(e) => {
            setFilter(e.target.value as typeof filter);
            setPage(1);
          }}
          className="border border-border rounded-lg px-4 py-2 bg-surface"
        >
          <option value="all">All statuses</option>
          <option value="new">New</option>
          <option value="contacted">Contacted</option>
          <option value="closed">Closed</option>
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
      {actionError && (
        <div className="bg-error/10 text-error rounded-lg px-4 py-3 mb-4">{actionError}</div>
      )}

      {!loading && !error && items.length === 0 && (
        <p className="text-text-secondary">No partner inquiries here.</p>
      )}

      {!loading && !error && (
        <div className="space-y-3">
          {items.map((q) => {
            const status: InquiryStatus = q.status ?? 'new';
            return (
              <div key={q.id} className="bg-surface border border-border p-4 rounded-xl">
                <div className="flex justify-between items-start gap-4 flex-wrap">
                  <div className="min-w-0">
                    <p className="font-semibold text-foreground">
                      {q.name}
                      {q.organization ? (
                        <span className="text-text-secondary font-normal"> · {q.organization}</span>
                      ) : null}
                    </p>
                    <a
                      href={`mailto:${q.email}`}
                      className="text-sm text-primary hover:underline break-all"
                    >
                      {q.email}
                    </a>
                    <p className="text-xs text-text-muted mt-0.5">{formatDateTime(q.created_at)}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      className={`text-xs px-3 py-1 rounded-full font-medium capitalize ${STATUS_STYLE[status]}`}
                    >
                      {status}
                    </span>
                    <select
                      value={status}
                      disabled={savingId === q.id}
                      onChange={(e) => changeStatus(q, e.target.value as InquiryStatus)}
                      className="border border-border rounded-lg px-2 py-1 text-sm bg-surface disabled:opacity-50"
                      aria-label={`Change status for ${q.name}`}
                    >
                      <option value="new">New</option>
                      <option value="contacted">Contacted</option>
                      <option value="closed">Closed</option>
                    </select>
                  </div>
                </div>
                <p className="text-sm text-foreground mt-3 whitespace-pre-wrap">{q.message}</p>
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
