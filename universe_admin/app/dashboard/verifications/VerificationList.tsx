'use client';

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Pager from '../../../components/Pager';
import { formatDate } from '../../../lib/format';
import {
  fetchVerifications,
  type VerificationItem,
  type VerificationStatus,
} from '../../../lib/verifications';

const COPY: Record<
  VerificationStatus,
  { title: string; subtitle: string; empty: string; badge: string; badgeClass: string }
> = {
  pending: {
    title: 'Pending Verifications',
    subtitle: 'Review and approve student verification requests.',
    empty: 'No pending verifications right now.',
    badge: 'Pending',
    badgeClass: 'bg-warning/15 text-warning',
  },
  approved: {
    title: 'Approved Verifications',
    subtitle: 'Students who have been verified.',
    empty: 'No approved verifications yet.',
    badge: 'Approved',
    badgeClass: 'bg-success/15 text-success',
  },
  rejected: {
    title: 'Rejected Verifications',
    subtitle: 'Students whose verification requests were rejected.',
    empty: 'No rejected verifications yet.',
    badge: 'Rejected',
    badgeClass: 'bg-error/15 text-error',
  },
};

const PAGE_SIZE = 25;

export default function VerificationList({ status }: { status: VerificationStatus }) {
  const copy = COPY[status];
  const [items, setItems] = useState<VerificationItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetchVerifications(status, page, PAGE_SIZE);
      if (res.success) {
        setItems(res.items);
        setTotal(res.total);
      } else {
        setError(res.error || 'Failed to load');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  }, [status, page]);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-foreground mb-1">{copy.title}</h1>
      <p className="text-text-secondary mb-6">{copy.subtitle}</p>

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
        <p className="text-text-secondary">{copy.empty}</p>
      )}

      {!loading && !error && (
        <div className="space-y-3">
          {items.map((v) => (
            <div
              key={v.id}
              onClick={() => router.push(`/dashboard/verifications/${v.id}`)}
              className="bg-surface border border-border p-4 rounded-xl cursor-pointer hover:border-primary transition flex justify-between items-center gap-4"
            >
              <div className="min-w-0">
                <p className="font-semibold text-foreground">{v.full_name}</p>
                <p className="text-sm text-text-secondary">
                  {v.matric_number} • {v.universities?.name ?? 'Unknown university'}
                </p>
                {status !== 'pending' && v.reviewed_at && (
                  <p className="text-xs text-text-muted mt-1">Reviewed {formatDate(v.reviewed_at)}</p>
                )}
                {status === 'rejected' && v.rejection_reason && (
                  <p className="text-xs text-error mt-1">Reason: {v.rejection_reason}</p>
                )}
              </div>
              <span className={`text-xs px-3 py-1 rounded-full font-medium shrink-0 ${copy.badgeClass}`}>
                {copy.badge}
              </span>
            </div>
          ))}
        </div>
      )}

      {!loading && !error && total > PAGE_SIZE && (
        <Pager page={page} pageSize={PAGE_SIZE} total={total} onChange={setPage} />
      )}
    </div>
  );
}
