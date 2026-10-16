'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { adminApi } from '../../../../lib/adminApi';
import { formatDateTime } from '../../../../lib/format';
import {
  fetchVerifications,
  type VerificationItem,
  type VerificationStatus,
} from '../../../../lib/verifications';

const STATUS_BADGE: Record<string, string> = {
  pending: 'bg-warning/15 text-warning',
  approved: 'bg-success/15 text-success',
  rejected: 'bg-error/15 text-error',
};

export default function VerificationDetailPage() {
  const [verification, setVerification] = useState<VerificationItem | null>(null);
  const [documentUrl, setDocumentUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);
  const [showApproveConfirm, setShowApproveConfirm] = useState(false);
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectBox, setShowRejectBox] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      // There is no GET /admin/verifications/:id endpoint, so we look for
      // this record in each status list (pending first, since that's where
      // admins usually arrive from). 100 is the backend's max page size.
      const statuses: VerificationStatus[] = ['pending', 'approved', 'rejected'];
      let found: VerificationItem | null = null;
      let lastError: string | null = null;
      for (const status of statuses) {
        const res = await fetchVerifications(status, 1, 100);
        if (!res.success) {
          lastError = res.error || 'Failed to load';
          continue;
        }
        found = res.items.find((v) => v.id === id) ?? null;
        if (found) break;
      }
      setVerification(found);
      if (!found && lastError) setError(lastError);

      const docData = await adminApi.get(`/admin/verifications/${id}/document-url`);
      if (docData.success) {
        setDocumentUrl(docData.url);
      }
    } catch {
      setError('Could not load verification details');
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async () => {
    setProcessing(true);
    setError(null);
    try {
      const data = await adminApi.patch(`/admin/verifications/${id}/approve`);
      if (data.success) {
        router.push('/dashboard/verifications');
      } else {
        setError(data.error || 'Failed to approve');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setProcessing(false);
    }
  };

  const handleReject = async () => {
    if (!rejectReason.trim()) {
      setError('Please provide a rejection reason');
      return;
    }
    setProcessing(true);
    setError(null);
    try {
      const data = await adminApi.patch(`/admin/verifications/${id}/reject`, {
        reason: rejectReason,
      });
      if (data.success) {
        router.push('/dashboard/verifications');
      } else {
        setError(data.error || 'Failed to reject');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setProcessing(false);
    }
  };

  if (loading) return <div className="p-8 text-text-secondary">Loading...</div>;
  if (!verification) {
    return (
      <div className="p-8">
        <p className="text-error mb-3">{error ?? 'Verification not found.'}</p>
        <button
          onClick={() => router.push('/dashboard/verifications')}
          className="text-primary font-semibold"
        >
          ← Back to list
        </button>
      </div>
    );
  }

  const isPending = verification.status === 'pending';

  return (
    <div className="p-8">
      <div className="max-w-2xl bg-surface border border-border rounded-2xl p-6">
        <button
          onClick={() => router.back()}
          className="text-primary mb-4 font-medium"
        >
          ← Back to list
        </button>

        <div className="flex items-start justify-between gap-3 mb-1">
          <h1 className="text-2xl font-bold text-foreground">{verification.full_name}</h1>
          <span
            className={`text-xs px-3 py-1 rounded-full font-medium capitalize ${
              STATUS_BADGE[verification.status] ?? 'bg-light-purple text-foreground'
            }`}
          >
            {verification.status}
          </span>
        </div>
        <p className="text-text-secondary mb-6">
          {verification.matric_number} • {verification.universities?.name ?? 'Unknown university'}
        </p>

        {!isPending && (
          <div className="bg-light-purple/50 rounded-lg px-4 py-3 mb-6 text-sm text-text-secondary">
            <p>Reviewed {formatDateTime(verification.reviewed_at)}</p>
            {verification.status === 'rejected' && verification.rejection_reason && (
              <p className="text-error mt-1">Reason: {verification.rejection_reason}</p>
            )}
          </div>
        )}

        {documentUrl && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={documentUrl}
            alt="Student ID"
            className="w-full rounded-xl border border-border mb-6"
          />
        )}

        {error && <p className="text-error mb-4">{error}</p>}

        {isPending &&
          (!showRejectBox && !showApproveConfirm ? (
            <div className="flex gap-3">
              <button
                onClick={() => setShowApproveConfirm(true)}
                disabled={processing}
                className="flex-1 bg-success text-white rounded-lg py-2 font-semibold hover:opacity-90 disabled:opacity-50 transition"
              >
                Approve
              </button>
              <button
                onClick={() => setShowRejectBox(true)}
                disabled={processing}
                className="flex-1 bg-error text-white rounded-lg py-2 font-semibold hover:opacity-90 disabled:opacity-50 transition"
              >
                Reject
              </button>
            </div>
          ) : showApproveConfirm ? (
            <div>
              <p className="text-foreground mb-3">
                Approve this verification? The student will be marked as a verified student and
                notified.
              </p>
              <div className="flex gap-3">
                <button
                  onClick={handleApprove}
                  disabled={processing}
                  className="flex-1 bg-success text-white rounded-lg py-2 font-semibold hover:opacity-90 disabled:opacity-50 transition"
                >
                  {processing ? 'Processing...' : 'Confirm Approval'}
                </button>
                <button
                  onClick={() => setShowApproveConfirm(false)}
                  disabled={processing}
                  className="flex-1 bg-light-purple text-foreground rounded-lg py-2 font-semibold hover:opacity-80 transition"
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : (
            <div>
              <textarea
                placeholder="Reason for rejection..."
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                className="w-full border border-border rounded-lg px-4 py-2 mb-3 focus:outline-none focus:ring-2 focus:ring-error"
                rows={3}
              />
              <div className="flex gap-3">
                <button
                  onClick={handleReject}
                  disabled={processing}
                  className="flex-1 bg-error text-white rounded-lg py-2 font-semibold hover:opacity-90 disabled:opacity-50 transition"
                >
                  {processing ? 'Processing...' : 'Confirm Rejection'}
                </button>
                <button
                  onClick={() => setShowRejectBox(false)}
                  className="flex-1 bg-light-purple text-foreground rounded-lg py-2 font-semibold hover:opacity-80 transition"
                >
                  Cancel
                </button>
              </div>
            </div>
          ))}
      </div>
    </div>
  );
}
