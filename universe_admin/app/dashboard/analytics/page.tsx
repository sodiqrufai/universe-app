'use client';

import { useEffect, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';

type DayBuckets = Record<string, number>;
type Analytics = {
  signupsByDay: DayBuckets;
  postsByDay: DayBuckets;
  verificationsSubmittedByDay: DayBuckets;
  verificationsApproved: number;
};

function BarChart({ title, data, color }: { title: string; data: DayBuckets; color: string }) {
  const days = Object.keys(data).sort();
  const max = Math.max(1, ...Object.values(data));
  const total = Object.values(data).reduce((a, b) => a + b, 0);

  return (
    <div className="bg-surface border border-border rounded-2xl p-5">
      <div className="flex items-baseline justify-between mb-4">
        <h3 className="font-semibold text-foreground">{title}</h3>
        <span className="text-sm text-text-secondary">{total} in last 30 days</span>
      </div>
      {days.length === 0 ? (
        <p className="text-text-muted text-sm">No data yet.</p>
      ) : (
        <div className="flex items-end gap-1 h-24">
          {days.map((day) => (
            <div key={day} className="flex-1 flex flex-col items-center justify-end h-full group relative">
              <div
                className={`w-full rounded-t ${color}`}
                style={{ height: `${Math.max(4, (data[day] / max) * 100)}%` }}
                title={`${day}: ${data[day]}`}
              />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default function AnalyticsPage() {
  const [analytics, setAnalytics] = useState<Analytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchAnalytics();
  }, []);

  const fetchAnalytics = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await adminApi.get('/admin/analytics');
      if (data.success) {
        setAnalytics(data.last30Days);
      } else {
        setError(data.error || 'Failed to load analytics');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-foreground mb-1">Analytics</h1>
      <p className="text-text-secondary mb-6">Last 30 days across the platform.</p>

      {loading && <p className="text-text-secondary">Loading...</p>}
      {error && (
        <div className="bg-error/10 text-error rounded-lg px-4 py-3 mb-4 flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchAnalytics} className="font-semibold underline">
            Retry
          </button>
        </div>
      )}

      {analytics && (
        <div className="space-y-4">
          <div className="bg-primary text-white rounded-2xl p-5 inline-block">
            <p className="text-3xl font-bold">{analytics.verificationsApproved}</p>
            <p className="text-sm text-white/80">Verifications approved (30d)</p>
          </div>
          <div className="grid md:grid-cols-3 gap-4">
            <BarChart title="Signups" data={analytics.signupsByDay} color="bg-primary" />
            <BarChart title="Posts Created" data={analytics.postsByDay} color="bg-success" />
            <BarChart title="Verifications Submitted" data={analytics.verificationsSubmittedByDay} color="bg-warning" />
          </div>
        </div>
      )}
    </div>
  );
}
