'use client';

import { useEffect, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';

type University = { id: string; name: string };

export default function AnnouncementsPage() {
  const [universities, setUniversities] = useState<University[]>([]);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [isGlobal, setIsGlobal] = useState(true);
  const [universityId, setUniversityId] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    adminApi.get('/admin/universities').then((data) => {
      if (data.success) setUniversities(data.universities);
    });
  }, []);

  const handleSend = async () => {
    if (!title.trim() || !body.trim()) return;
    if (!isGlobal && !universityId) {
      setError('Pick a university, or mark this as global.');
      return;
    }
    setSending(true);
    setError(null);
    setSuccess(false);
    try {
      const data = await adminApi.post('/admin/announcements', {
        title: title.trim(),
        body: body.trim(),
        isGlobal,
        universityId: isGlobal ? undefined : universityId,
      });
      if (data.success) {
        setTitle('');
        setBody('');
        setSuccess(true);
      } else {
        setError(data.error || 'Failed to send announcement');
      }
    } catch {
      setError('Could not connect to server');
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold text-foreground mb-1">Announcements</h1>
      <p className="text-text-secondary mb-6">
        Posted announcements feed straight into students&apos; Feed tab. There&apos;s no history view
        here yet — the backend only has a send endpoint, not a list one.
      </p>

      <div className="bg-surface border border-border rounded-2xl p-6 max-w-xl">
        <label className="block text-sm font-medium text-text-secondary mb-1">Title</label>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className="w-full border border-border rounded-lg px-4 py-2 mb-4 focus:outline-none focus:ring-2 focus:ring-primary"
        />

        <label className="block text-sm font-medium text-text-secondary mb-1">Body</label>
        <textarea
          value={body}
          onChange={(e) => setBody(e.target.value)}
          rows={4}
          className="w-full border border-border rounded-lg px-4 py-2 mb-4 focus:outline-none focus:ring-2 focus:ring-primary"
        />

        <label className="flex items-center gap-2 mb-4 text-sm text-foreground">
          <input type="checkbox" checked={isGlobal} onChange={(e) => setIsGlobal(e.target.checked)} />
          Send to all universities (global)
        </label>

        {!isGlobal && (
          <>
            <label className="block text-sm font-medium text-text-secondary mb-1">University</label>
            <select
              value={universityId}
              onChange={(e) => setUniversityId(e.target.value)}
              className="w-full border border-border rounded-lg px-4 py-2 mb-4 bg-surface"
            >
              <option value="">Select a university...</option>
              {universities.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.name}
                </option>
              ))}
            </select>
          </>
        )}

        {error && <p className="text-error text-sm mb-3">{error}</p>}
        {success && <p className="text-success text-sm mb-3">Announcement sent.</p>}

        <button
          onClick={handleSend}
          disabled={sending || !title.trim() || !body.trim()}
          className="bg-primary text-white rounded-lg px-6 py-2 font-semibold hover:bg-primary-dark disabled:opacity-50 transition"
        >
          {sending ? 'Sending...' : 'Send Announcement'}
        </button>
      </div>
    </div>
  );
}
