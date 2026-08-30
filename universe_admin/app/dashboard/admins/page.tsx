'use client';

import { useEffect, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';

type Admin = { id: string; full_name: string; username: string; role: string };

const ROLES = ['student', 'moderator', 'university_admin', 'super_admin'];

export default function AdminsPage() {
  const [admins, setAdmins] = useState<Admin[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirmTarget, setConfirmTarget] = useState<{ admin: Admin; newRole: string } | null>(null);

  useEffect(() => {
    fetchAdmins();
  }, []);

  const fetchAdmins = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await adminApi.get('/admin/admins');
      if (data.success) {
        setAdmins(data.admins);
      } else if (data.restricted) {
        setError(data.error || 'This page requires super_admin access.');
      } else {
        setError(data.error || 'Failed to load admins');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  };

  const handleRoleChange = async () => {
    if (!confirmTarget) return;
    try {
      const data = await adminApi.patch(`/admin/admins/${confirmTarget.admin.id}`, {
        role: confirmTarget.newRole,
        confirm: true,
      });
      if (data.success) {
        setConfirmTarget(null);
        fetchAdmins();
      } else {
        setError(data.error || 'Could not update role');
      }
    } catch {
      setError('Could not update role');
    }
  };

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-foreground mb-1">Admin Management</h1>
      <p className="text-text-secondary mb-6">
        Everyone here has moderator role or higher. Only super_admins can change roles.
      </p>

      {loading && <p className="text-text-secondary">Loading...</p>}
      {error && (
        <div className="bg-error/10 text-error rounded-lg px-4 py-3 mb-4 flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchAdmins} className="font-semibold underline">
            Retry
          </button>
        </div>
      )}

      {!loading && !error && (
        <div className="bg-surface border border-border rounded-2xl overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-light-purple/40 text-text-secondary text-left">
              <tr>
                <th className="px-4 py-3 font-medium">Name</th>
                <th className="px-4 py-3 font-medium">Role</th>
                <th className="px-4 py-3 font-medium text-right">Change Role</th>
              </tr>
            </thead>
            <tbody>
              {admins.map((a) => (
                <tr key={a.id} className="border-t border-border">
                  <td className="px-4 py-3">
                    <p className="font-medium text-foreground">{a.full_name}</p>
                    <p className="text-text-muted text-xs">@{a.username}</p>
                  </td>
                  <td className="px-4 py-3">
                    <span className="text-xs bg-light-purple text-primary px-2 py-1 rounded-full font-medium capitalize">
                      {a.role.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right">
                    <select
                      value={a.role}
                      onChange={(e) => setConfirmTarget({ admin: a, newRole: e.target.value })}
                      className="border border-border rounded-lg px-3 py-1.5 text-xs bg-surface"
                    >
                      {ROLES.map((r) => (
                        <option key={r} value={r}>
                          {r.replace('_', ' ')}
                        </option>
                      ))}
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {confirmTarget && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-surface rounded-2xl p-6 max-w-sm w-full">
            <h2 className="text-lg font-bold text-foreground mb-2">Change role?</h2>
            <p className="text-text-secondary text-sm mb-5">
              Set {confirmTarget.admin.full_name}&apos;s role to{' '}
              <strong className="text-foreground">{confirmTarget.newRole.replace('_', ' ')}</strong>?
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setConfirmTarget(null)}
                className="flex-1 bg-light-purple text-foreground rounded-lg py-2 font-semibold"
              >
                Cancel
              </button>
              <button
                onClick={handleRoleChange}
                className="flex-1 bg-primary text-white rounded-lg py-2 font-semibold hover:bg-primary-dark"
              >
                Confirm
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
