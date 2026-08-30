'use client';

import { useEffect, useState } from 'react';
import { adminApi } from '../../lib/adminApi';

type Stats = {
  totalStudents: number;
  pendingVerifications: number;
  openReports: number;
  activeListings: number;
  activeEvents: number;
};

export default function DashboardOverviewPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchStats();
  }, []);

  const fetchStats = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await adminApi.get('/admin/dashboard');
      if (data.success) {
        setStats(data.stats);
      } else {
        setError(data.error || 'Failed to load dashboard');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  };

  const cards = stats
    ? [
        { label: 'Total Students', value: stats.totalStudents, color: 'text-primary' },
        { label: 'Pending Verifications', value: stats.pendingVerifications, color: 'text-warning' },
        { label: 'Open Reports', value: stats.openReports, color: 'text-error' },
        { label: 'Active Listings', value: stats.activeListings, color: 'text-success' },
        { label: 'Active Events', value: stats.activeEvents, color: 'text-info' },
      ]
    : [];

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-foreground mb-1">Overview</h1>
      <p className="text-text-secondary mb-6">Platform snapshot, right now.</p>

      {loading && <p className="text-text-secondary">Loading...</p>}
      {error && (
        <div className="bg-error/10 text-error rounded-lg px-4 py-3 mb-4 flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchStats} className="font-semibold underline">
            Retry
          </button>
        </div>
      )}

      {!loading && !error && (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
          {cards.map((c) => (
            <div key={c.label} className="bg-surface border border-border rounded-2xl p-5">
              <p className={`text-3xl font-bold ${c.color}`}>{c.value}</p>
              <p className="text-sm text-text-secondary mt-1">{c.label}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
