'use client';

import { useEffect, useRef, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';
import { API_BASE_URL } from '../../../lib/apiConfig';

type University = { id: string; name: string };

export default function AnnouncementsPage() {
  const [universities, setUniversities] = useState<University[]>([]);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [isGlobal, setIsGlobal] = useState(true);
  const [universityId, setUniversityId] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [image, setImage] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    adminApi.get('/admin/universities').then((data) => {
      if (data.success) setUniversities(data.universities);
    });
  }, []);

  const handleImagePick = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setImage(file);
    setImagePreview(URL.createObjectURL(file));
  };

  const clearImage = () => {
    setImage(null);
    if (imagePreview) URL.revokeObjectURL(imagePreview);
    setImagePreview(null);
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  const handleSend = async () => {
    if (!title.trim() || !body.trim()) return;
    if (!isGlobal && !universityId) {
      setError('Pick a university, or mark this as global.');
      return;
    }
    setSending(true);
    setError(null);
    setSuccess(null);
    try {
      // adminApi.post always JSON-encodes — a file can't ride along in
      // a JSON body, so this bypasses it for a direct multipart fetch,
      // same exception mobile's ApiService makes for image/avatar
      // uploads. Falls back to the normal JSON path when there's no
      // image at all, since that still works today either way.
      let data;
      if (image) {
        const token = localStorage.getItem('admin_token');
        const formData = new FormData();
        formData.append('title', title.trim());
        formData.append('body', body.trim());
        formData.append('isGlobal', String(isGlobal));
        if (!isGlobal) formData.append('universityId', universityId);
        formData.append('file', image);

        const res = await fetch(`${API_BASE_URL}/admin/announcements`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${token}` },
          body: formData,
        });
        data = await res.json();
      } else {
        data = await adminApi.post('/admin/announcements', {
          title: title.trim(),
          body: body.trim(),
          isGlobal,
          universityId: isGlobal ? undefined : universityId,
        });
      }

      if (data.success) {
        setTitle('');
        setBody('');
        clearImage();
        setSuccess(
          data.imageUploadFailed
            ? 'Announcement sent, but the image failed to attach. You can edit the announcement to try adding it again.'
            : 'Announcement sent.',
        );
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

        <label className="block text-sm font-medium text-text-secondary mb-1">Image (optional)</label>
        <div className="mb-4">
          {imagePreview ? (
            <div className="relative inline-block">
              <img src={imagePreview} alt="Announcement preview" className="h-32 rounded-lg border border-border object-cover" />
              <button
                type="button"
                onClick={clearImage}
                className="absolute -top-2 -right-2 bg-surface border border-border rounded-full w-6 h-6 flex items-center justify-center text-text-secondary hover:text-error"
                aria-label="Remove image"
              >
                ×
              </button>
            </div>
          ) : (
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              onChange={handleImagePick}
              className="w-full text-sm text-text-secondary file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:bg-primary file:text-white file:font-semibold hover:file:bg-primary-dark file:cursor-pointer"
            />
          )}
        </div>

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
        {success && (
          <p className={`text-sm mb-3 ${success.includes('failed') ? 'text-warning' : 'text-success'}`}>
            {success}
          </p>
        )}

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
