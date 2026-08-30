'use client';

import { useEffect, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';

type University = {
  id: string;
  name: string;
  short_name: string | null;
  city: string | null;
  country: string | null;
  ownership_type: string | null;
};

const emptyForm = { name: '', shortName: '', city: '', country: 'Nigeria', ownershipType: 'private' };

export default function UniversitiesPage() {
  const [universities, setUniversities] = useState<University[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<University | null>(null);
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchUniversities();
  }, []);

  const fetchUniversities = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await adminApi.get('/admin/universities');
      if (data.success) {
        setUniversities(data.universities);
      } else {
        setError(data.error || 'Failed to load universities');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setLoading(false);
    }
  };

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm);
    setShowForm(true);
  };

  const openEdit = (u: University) => {
    setEditing(u);
    setForm({
      name: u.name,
      shortName: u.short_name ?? '',
      city: u.city ?? '',
      country: u.country ?? 'Nigeria',
      ownershipType: u.ownership_type ?? 'private',
    });
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!form.name.trim()) return;
    setSaving(true);
    setError(null);
    try {
      const data = editing
        ? await adminApi.patch(`/admin/universities/${editing.id}`, {
            name: form.name.trim(),
            short_name: form.shortName.trim() || null,
            city: form.city.trim() || null,
            country: form.country.trim() || null,
            ownership_type: form.ownershipType,
          })
        : await adminApi.post('/admin/universities', {
            name: form.name.trim(),
            shortName: form.shortName.trim() || undefined,
            city: form.city.trim() || undefined,
            country: form.country.trim() || undefined,
            ownershipType: form.ownershipType,
          });
      if (data.success) {
        setShowForm(false);
        fetchUniversities();
      } else if (data.restricted) {
        setError(data.error || 'This requires university_admin access or higher.');
      } else {
        setError(data.error || 'Could not save university');
      }
    } catch {
      setError('Could not save university');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="p-8">
      <div className="flex items-center justify-between mb-1">
        <h1 className="text-2xl font-bold text-foreground">Universities</h1>
        <button
          onClick={openCreate}
          className="bg-primary text-white rounded-lg px-4 py-2 text-sm font-semibold hover:bg-primary-dark transition"
        >
          + Add University
        </button>
      </div>
      <p className="text-text-secondary mb-6">{universities.length} universities on the platform.</p>

      {loading && <p className="text-text-secondary">Loading...</p>}
      {error && !showForm && (
        <div className="bg-error/10 text-error rounded-lg px-4 py-3 mb-4 flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchUniversities} className="font-semibold underline">
            Retry
          </button>
        </div>
      )}

      {!loading && (
        <div className="bg-surface border border-border rounded-2xl overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-light-purple/40 text-text-secondary text-left">
              <tr>
                <th className="px-4 py-3 font-medium">Name</th>
                <th className="px-4 py-3 font-medium">City</th>
                <th className="px-4 py-3 font-medium">Ownership</th>
                <th className="px-4 py-3 font-medium text-right">Action</th>
              </tr>
            </thead>
            <tbody>
              {universities.map((u) => (
                <tr key={u.id} className="border-t border-border">
                  <td className="px-4 py-3">
                    <p className="font-medium text-foreground">{u.name}</p>
                    {u.short_name && <p className="text-text-muted text-xs">{u.short_name}</p>}
                  </td>
                  <td className="px-4 py-3 text-text-secondary">{u.city ?? '—'}</td>
                  <td className="px-4 py-3 text-text-secondary capitalize">{u.ownership_type ?? '—'}</td>
                  <td className="px-4 py-3 text-right">
                    <button onClick={() => openEdit(u)} className="text-xs font-semibold text-primary underline">
                      Edit
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {showForm && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-surface rounded-2xl p-6 max-w-md w-full">
            <h2 className="text-lg font-bold text-foreground mb-4">
              {editing ? 'Edit University' : 'Add University'}
            </h2>
            <div className="space-y-3">
              <input
                placeholder="Name"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                className="w-full border border-border rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-primary"
              />
              <input
                placeholder="Short name (optional)"
                value={form.shortName}
                onChange={(e) => setForm({ ...form, shortName: e.target.value })}
                className="w-full border border-border rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-primary"
              />
              <input
                placeholder="City"
                value={form.city}
                onChange={(e) => setForm({ ...form, city: e.target.value })}
                className="w-full border border-border rounded-lg px-4 py-2 focus:outline-none focus:ring-2 focus:ring-primary"
              />
              <select
                value={form.ownershipType}
                onChange={(e) => setForm({ ...form, ownershipType: e.target.value })}
                className="w-full border border-border rounded-lg px-4 py-2 bg-surface"
              >
                <option value="federal">Federal</option>
                <option value="state">State</option>
                <option value="private">Private</option>
              </select>
            </div>
            {error && <p className="text-error text-sm mt-3">{error}</p>}
            <div className="flex gap-3 mt-5">
              <button
                onClick={() => {
                  setShowForm(false);
                  setError(null);
                }}
                className="flex-1 bg-light-purple text-foreground rounded-lg py-2 font-semibold"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={saving || !form.name.trim()}
                className="flex-1 bg-primary text-white rounded-lg py-2 font-semibold hover:bg-primary-dark disabled:opacity-50"
              >
                {saving ? 'Saving...' : 'Save'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
