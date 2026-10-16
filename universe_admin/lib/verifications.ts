import { adminApi } from './adminApi';

export type VerificationStatus = 'pending' | 'approved' | 'rejected';

export type VerificationItem = {
  id: string;
  full_name: string;
  matric_number: string;
  status: string;
  created_at?: string;
  reviewed_at?: string | null;
  rejection_reason?: string | null;
  universities: { name: string } | null;
};

export type VerificationPage = {
  success: boolean;
  error?: string;
  items: VerificationItem[];
  total: number;
  page: number;
  pageSize: number;
};

/**
 * Loads one page of verifications for a status.
 *
 * Uses GET /admin/verifications?status=... ({success, items, verifications,
 * total, page, pageSize}), which the backend now provides. The fallback to
 * the older /admin/verifications/pending|approved|rejected routes (still
 * live, unchanged) only matters if the backend deploy is older than this
 * admin build, and can be deleted later.
 */
export async function fetchVerifications(
  status: VerificationStatus,
  page: number,
  pageSize: number,
): Promise<VerificationPage> {
  const params = new URLSearchParams({ status, page: String(page), pageSize: String(pageSize) });
  const data = await adminApi.get(`/admin/verifications?${params}`);
  if (data.success && Array.isArray(data.items)) {
    return {
      success: true,
      items: data.items,
      total: data.total ?? data.items.length,
      page: data.page ?? page,
      pageSize: data.pageSize ?? pageSize,
    };
  }

  // Fallback: old endpoints. 403 (no permission) is a real answer, don't mask it.
  if (data.restricted) {
    return { success: false, error: data.error || 'Not allowed', items: [], total: 0, page, pageSize };
  }
  const legacyQuery = status === 'pending' ? '' : `?page=${page}&pageSize=${pageSize}`;
  const legacy = await adminApi.get(`/admin/verifications/${status}${legacyQuery}`);
  if (legacy.success && Array.isArray(legacy.verifications)) {
    const all: VerificationItem[] = legacy.verifications;
    // The legacy pending endpoint isn't paginated; slice it locally.
    const items = status === 'pending' ? all.slice((page - 1) * pageSize, page * pageSize) : all;
    return {
      success: true,
      items,
      total: legacy.total ?? all.length,
      page,
      pageSize,
    };
  }
  return {
    success: false,
    error: data.error || legacy.error || 'Failed to load',
    items: [],
    total: 0,
    page,
    pageSize,
  };
}
