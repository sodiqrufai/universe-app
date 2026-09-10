'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { adminApi } from '../../../../lib/adminApi';

type Verification = {
  id: string;
  full_name: string;
  matric_number: string;
  status: string;
  rejection_reason: string | null;
  reviewed_at: string;
  universities: { name: string } | null;
};

export default function RejectedVerificationsPage() {
  const [verifications, setVerifications] = useState<Verification[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  useEffect(() => {
    fetchRejected();
  }, []);

  const fetchRejected = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await adminApi.get('/admin/verifications/rejected');
      if (data.success) {
        setVerifications(data.verifications);
      } else {
        setError(data.error || 'Failed to load');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-foreground mb-1">Rejected Verifications</h1>
      <p className="text-text-secondary mb-6">Students whose verification requests were rejected.</p>

      {loading && <p className="text-text-secondary">Loading...</p>}
      {error && (
        <div className="bg-error/10 text-error rounded-lg px-4 py-3 mb-4 flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchRejected} className="font-semibold underline">
            Retry
          </button>
        </div>
      )}

      {!loading && !error && verifications.length === 0 && (
        <p className="text-text-secondary">No rejected verifications yet.</p>
      )}

      <div className="space-y-3">
        {verifications.map((v) => (
          <div
            key={v.id}
            onClick={() => router.push(`/dashboard/verifications/${v.id}`)}
            className="bg-surface border border-border p-4 rounded-xl cursor-pointer hover:border-primary transition flex justify-between items-center"
          >
            <div>
              <p className="font-semibold text-foreground">{v.full_name}</p>
              <p className="text-sm text-text-secondary">
                {v.matric_number} • {v.universities?.name ?? 'Unknown university'}
              </p>
              {v.rejection_reason && (
                <p className="text-xs text-error mt-1">Reason: {v.rejection_reason}</p>
              )}
            </div>
            <span className="text-xs bg-error/15 text-error px-3 py-1 rounded-full font-medium">
              Rejected
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
