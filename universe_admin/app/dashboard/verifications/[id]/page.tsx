'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { adminApi } from '../../../../lib/adminApi';

type VerificationDetail = {
  id: string;
  full_name: string;
  matric_number: string;
  status: string;
  created_at: string;
  universities: { name: string } | null;
};

export default function VerificationDetailPage() {
  const [verification, setVerification] = useState<VerificationDetail | null>(null);
  const [documentUrl, setDocumentUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);
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
      // No dedicated GET /admin/verifications/:id endpoint exists yet —
      // the only way to fetch one is within the pending list, same
      // approach the original page used. This means a verification
      // that's already been approved/rejected by someone else won't be
      // found here; that's a real backend gap, not something fixable
      // from this page alone.
      const [pendingData, docData] = await Promise.all([
        adminApi.get('/admin/verifications/pending'),
        adminApi.get(`/admin/verifications/${id}/document-url`),
      ]);

      if (pendingData.success) {
        const found = pendingData.verifications.find((v: VerificationDetail) => v.id === id);
        setVerification(found ?? null);
      } else {
        setError(pendingData.error || 'Failed to load');
      }
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
        <p className="text-error mb-3">
          Verification not found — it may have already been reviewed by someone else.
        </p>
        <button
          onClick={() => router.push('/dashboard/verifications')}
          className="text-primary font-semibold"
        >
          ← Back to list
        </button>
      </div>
    );
  }

  return (
    <div className="p-8">
      <div className="max-w-2xl bg-surface border border-border rounded-2xl p-6">
        <button
          onClick={() => router.push('/dashboard/verifications')}
          className="text-primary mb-4 font-medium"
        >
          ← Back to list
        </button>

        <h1 className="text-2xl font-bold text-foreground mb-1">{verification.full_name}</h1>
        <p className="text-text-secondary mb-6">
          {verification.matric_number} • {verification.universities?.name ?? 'Unknown university'}
        </p>

        {documentUrl && (
          <img
            src={documentUrl}
            alt="Student ID"
            className="w-full rounded-xl border border-border mb-6"
          />
        )}

        {error && <p className="text-error mb-4">{error}</p>}

        {!showRejectBox ? (
          <div className="flex gap-3">
            <button
              onClick={handleApprove}
              disabled={processing}
              className="flex-1 bg-success text-white rounded-lg py-2 font-semibold hover:opacity-90 disabled:opacity-50 transition"
            >
              {processing ? 'Processing...' : 'Approve'}
            </button>
            <button
              onClick={() => setShowRejectBox(true)}
              disabled={processing}
              className="flex-1 bg-error text-white rounded-lg py-2 font-semibold hover:opacity-90 disabled:opacity-50 transition"
            >
              Reject
            </button>
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
        )}
      </div>
    </div>
  );
}
