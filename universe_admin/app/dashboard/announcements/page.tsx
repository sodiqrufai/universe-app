'use client';

import { useEffect, useRef, useState } from 'react';
import { adminApi } from '../../../lib/adminApi';
import { API_BASE_URL } from '../../../lib/apiConfig';

type University = { id: string; name: string };
type Announcement = {
  id: string;
  title: string;
  body: string;
  image_url: string | null;
  is_global: boolean;
  university_id: string | null;
  created_at: string;
};

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

  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [listLoading, setListLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const pageSize = 25;
  const [confirmTarget, setConfirmTarget] = useState<Announcement | null>(null);
  const [deleting, setDeleting] = useState(false);

  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  const fetchAnnouncements = async () => {
    setListLoading(true);
    const data = await adminApi.get(`/admin/announcements?page=${page}&pageSize=${pageSize}`);
    if (data.success) {
      // Response key is `announcements`, not the generic `items` other
      // paginated admin endpoints use — checked admin.controller.ts
      // directly rather than assuming it matched Students/Reports.
      setAnnouncements(data.announcements);
      setTotal(data.total);
    }
    setListLoading(false);
  };

  useEffect(() => {
    fetchAnnouncements();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page]);

  const handleDelete = async (announcement: Announcement) => {
    setDeleting(true);
    const data = await adminApi.delete(`/admin/announcements/${announcement.id}`);
    setDeleting(false);
    setConfirmTarget(null);
    if (data.success) {
      fetchAnnouncements();
    }
  };

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
        setPage(1);
        fetchAnnouncements();
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
        Posted announcements feed straight into students&apos; Feed tab.
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

      <div className="bg-surface border border-border rounded-2xl p-6 max-w-xl mt-8">
        <h2 className="text-lg font-bold text-foreground mb-4">History</h2>

        {listLoading ? (
          <p className="text-text-secondary text-sm">Loading...</p>
        ) : announcements.length === 0 ? (
          <p className="text-text-secondary text-sm">No announcements sent yet.</p>
        ) : (
          <>
            <div className="flex flex-col gap-3">
              {announcements.map((a) => (
                <div
                  key={a.id}
                  className="flex items-start gap-3 border border-border rounded-lg p-3"
                >
                  {a.image_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={a.image_url}
                      alt=""
                      className="w-14 h-14 rounded-lg object-cover flex-shrink-0"
                    />
                  ) : (
                    <div className="w-14 h-14 rounded-lg bg-light-purple flex-shrink-0" />
                  )}
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-foreground truncate">{a.title}</p>
                    <p className="text-text-secondary text-sm truncate">{a.body}</p>
                    <p className="text-text-muted text-xs mt-1">
                      {a.is_global ? 'All universities' : 'Single university'} ·{' '}
                      {new Date(a.created_at).toLocaleDateString()}
                    </p>
                  </div>
                  <button
                    onClick={() => setConfirmTarget(a)}
                    aria-label={`Delete ${a.title}`}
                    className="text-text-secondary hover:text-error p-1 flex-shrink-0"
                  >
                    🗑
                  </button>
                </div>
              ))}
            </div>

            <div className="flex items-center justify-between mt-4">
              <p className="text-sm text-text-secondary">
                Page {page} of {totalPages}
              </p>
              <div className="flex gap-2">
                <button
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                  disabled={page <= 1}
                  className="px-3 py-1.5 rounded-lg border border-border text-sm disabled:opacity-40"
                >
                  Previous
                </button>
                <button
                  onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  disabled={page >= totalPages}
                  className="px-3 py-1.5 rounded-lg border border-border text-sm disabled:opacity-40"
                >
                  Next
                </button>
              </div>
            </div>
          </>
        )}
      </div>

      {confirmTarget && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-surface rounded-2xl p-6 max-w-sm w-full">
            <h2 className="text-lg font-bold text-foreground mb-2">
              Delete &quot;{confirmTarget.title}&quot;?
            </h2>
            <p className="text-text-secondary text-sm mb-5">
              This removes it from students&apos; Feed tab immediately. This cannot be undone.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setConfirmTarget(null)}
                disabled={deleting}
                className="flex-1 bg-light-purple text-foreground rounded-lg py-2 font-semibold disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={() => handleDelete(confirmTarget)}
                disabled={deleting}
                className="flex-1 bg-error text-white rounded-lg py-2 font-semibold hover:opacity-90 disabled:opacity-50"
              >
                {deleting ? 'Deleting...' : 'Confirm'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
