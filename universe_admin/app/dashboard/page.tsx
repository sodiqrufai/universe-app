'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

type Verification = {
  id: string;
  full_name: string;
  matric_number: string;
  status: string;
  created_at: string;
  universities: { name: string } | null;
};

export default function DashboardPage() {
  const [verifications, setVerifications] = useState<Verification[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  useEffect(() => {
    const token = localStorage.getItem('admin_token');
    if (!token) {
      router.push('/login');
      return;
    }
    fetchPending(token);
  }, []);

  const fetchPending = async (token: string) => {
    try {
      const res = await fetch('${ApiConfig.baseUrl}/admin/verifications/pending', {
        headers: { Authorization: `Bearer ${token}` },
      });
      const data = await res.json();
      if (data.success) {
        setVerifications(data.verifications);
      } else {
        setError(data.error || data.message || 'Failed to load');
      }
    } catch (e) {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-2xl font-bold text-gray-900 mb-1">Pending Verifications</h1>
        <p className="text-gray-500 mb-6">Review and approve student verification requests.</p>

        {loading && <p className="text-gray-500">Loading...</p>}
        {error && <p className="text-red-500">{error}</p>}

        {!loading && !error && verifications.length === 0 && (
          <p className="text-gray-500">No pending verifications right now.</p>
        )}

        <div className="space-y-3">
          {verifications.map((v) => (
            <div
              key={v.id}
              onClick={() => router.push(`/dashboard/${v.id}`)}
              className="bg-white p-4 rounded-xl shadow-sm cursor-pointer hover:shadow-md transition flex justify-between items-center"
            >
              <div>
                <p className="font-semibold text-gray-900">{v.full_name}</p>
                <p className="text-sm text-gray-500">
                  {v.matric_number} • {v.universities?.name ?? 'Unknown university'}
                </p>
              </div>
              <span className="text-xs bg-orange-100 text-orange-700 px-3 py-1 rounded-full">
                Pending
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}