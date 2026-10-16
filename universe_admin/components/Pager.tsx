'use client';

// Previous / Next control used by every paginated admin list.
export default function Pager({
  page,
  pageSize,
  total,
  onChange,
}: {
  page: number;
  pageSize: number;
  total: number;
  onChange: (page: number) => void;
}) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  return (
    <div className="flex items-center justify-between mt-4">
      <p className="text-sm text-text-secondary">
        Page {page} of {totalPages}
      </p>
      <div className="flex gap-2">
        <button
          onClick={() => onChange(Math.max(1, page - 1))}
          disabled={page <= 1}
          className="px-3 py-1.5 rounded-lg border border-border text-sm disabled:opacity-40"
        >
          Previous
        </button>
        <button
          onClick={() => onChange(Math.min(totalPages, page + 1))}
          disabled={page >= totalPages}
          className="px-3 py-1.5 rounded-lg border border-border text-sm disabled:opacity-40"
        >
          Next
        </button>
      </div>
    </div>
  );
}
