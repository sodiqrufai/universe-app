'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';

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
    const token = localStorage.getItem('admin_token');
    if (!token) {
      router.push('/login');
      return;
    }
    load(token);
  }, []);

  const load = async (token: string) => {
    try {
      const [pendingRes, docRes] = await Promise.all([
        fetch('http://localhost:3000/admin/verifications/pending', {
          headers: { Authorization: `Bearer ${token}` },
        }),
        fetch(`http://localhost:3000/admin/verifications/${id}/document-url`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
      ]);
      const pendingData = await pendingRes.json();
      const docData = await docRes.json();

      if (pendingData.success) {
        const found = pendingData.verifications.find((v: VerificationDetail) => v.id === id);
        setVerification(found ?? null);
      }
      if (docData.success) {
        setDocumentUrl(docData.url);
      }
    } catch (e) {
      setError('Could not load verification details');
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async () => {
    setProcessing(true);
    const token = localStorage.getItem('admin_token');
    try {
      const res = await fetch(`http://localhost:3000/admin/verifications/${id}/approve`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      if (data.success) {
        router.push('/dashboard');
      } else {
        setError(data.error || 'Failed to approve');
      }
    } catch (e) {
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
    const token = localStorage.getItem('admin_token');
    try {
      const res = await fetch(`http://localhost:3000/admin/verifications/${id}/reject`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason: rejectReason }),
      });
      const data = await res.json();
      if (data.success) {
        router.push('/dashboard');
      } else {
        setError(data.error || 'Failed to reject');
      }
    } catch (e) {
      setError('Could not connect to server');
    } finally {
      setProcessing(false);
    }
  };

  if (loading) return <div className="p-8 text-gray-500">Loading...</div>;
  if (!verification) return <div className="p-8 text-red-500">Verification not found</div>;

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-2xl mx-auto bg-white rounded-2xl shadow-sm p-6">
        <button onClick={() => router.push('/dashboard')} className="text-indigo-700 mb-4">
          ← Back to list
        </button>

        <h1 className="text-2xl font-bold text-gray-900 mb-1">{verification.full_name}</h1>
        <p className="text-gray-500 mb-6">
          {verification.matric_number} • {verification.universities?.name ?? 'Unknown university'}
        </p>

        {documentUrl && (
          <img
            src={documentUrl}
            alt="Student ID"
            className="w-full rounded-xl border border-gray-200 mb-6"
          />
        )}

        {error && <p className="text-red-500 mb-4">{error}</p>}

        {!showRejectBox ? (
          <div className="flex gap-3">
            <button
              onClick={handleApprove}
              disabled={processing}
              className="flex-1 bg-green-600 text-white rounded-lg py-2 font-semibold hover:bg-green-700 disabled:opacity-50"
            >
              {processing ? 'Processing...' : 'Approve'}
            </button>
            <button
              onClick={() => setShowRejectBox(true)}
              disabled={processing}
              className="flex-1 bg-red-600 text-white rounded-lg py-2 font-semibold hover:bg-red-700 disabled:opacity-50"
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
              className="w-full border border-gray-200 rounded-lg px-4 py-2 mb-3 focus:outline-none focus:ring-2 focus:ring-red-500"
              rows={3}
            />
            <div className="flex gap-3">
              <button
                onClick={handleReject}
                disabled={processing}
                className="flex-1 bg-red-600 text-white rounded-lg py-2 font-semibold hover:bg-red-700 disabled:opacity-50"
              >
                {processing ? 'Processing...' : 'Confirm Rejection'}
              </button>
              <button
                onClick={() => setShowRejectBox(false)}
                className="flex-1 bg-gray-200 text-gray-800 rounded-lg py-2 font-semibold hover:bg-gray-300"
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