import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Query, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { NotificationsService } from '../notifications/notifications.service';

const ROLE_RANK: Record<string, number> = {
  student: 0,
  moderator: 1,
  university_admin: 2,
  super_admin: 3,
};

@Controller('admin')
export class AdminController {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly notifications: NotificationsService,
  ) {}

  private async getAdminFromToken(authHeader?: string, minRole: string = 'moderator') {
    if (!authHeader?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing token');
    }
    const token = authHeader.replace('Bearer ', '');
    const { data, error } = await this.supabase.client.auth.getUser(token);
    if (error || !data.user) {
      throw new UnauthorizedException('Invalid token');
    }

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('role')
      .eq('id', data.user.id)
      .single();

    const rank = ROLE_RANK[profile?.role ?? 'student'] ?? 0;
    if (rank < ROLE_RANK[minRole]) {
      throw new ForbiddenException(`Requires ${minRole} role or higher`);
    }

    return { ...data.user, role: profile?.role };
  }

  private async logAction(adminId: string, action: string, targetType: string, targetId?: string, metadata?: Record<string, any>) {
    await this.supabase.client.from('admin_audit_log').insert({
      admin_id: adminId,
      action,
      target_type: targetType,
      target_id: targetId ?? null,
      metadata: metadata ?? null,
    });
  }

  // ---------- Dashboard ----------

  @Get('dashboard')
  async getDashboard(@Headers('authorization') authHeader: string) {
    await this.getAdminFromToken(authHeader);

    const [students, pendingVerifications, openReports, activeListings, activeEvents] = await Promise.all([
      this.supabase.client.from('profiles').select('id', { count: 'exact', head: true }),
      this.supabase.client.from('verifications').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
      this.supabase.client.from('reports').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
      this.supabase.client.from('listings').select('id', { count: 'exact', head: true }).eq('status', 'active'),
      this.supabase.client.from('events').select('id', { count: 'exact', head: true }).eq('status', 'active'),
    ]);

    return {
      success: true,
      stats: {
        totalStudents: students.count ?? 0,
        pendingVerifications: pendingVerifications.count ?? 0,
        openReports: openReports.count ?? 0,
        activeListings: activeListings.count ?? 0,
        activeEvents: activeEvents.count ?? 0,
      },
    };
  }

  @Get('analytics')
  async getAnalytics(@Headers('authorization') authHeader: string) {
    await this.getAdminFromToken(authHeader);

    const since = new Date();
    since.setDate(since.getDate() - 30);
    const sinceIso = since.toISOString();

    const [signups, posts, verifications] = await Promise.all([
      this.supabase.client.from('profiles').select('created_at').gte('created_at', sinceIso),
      this.supabase.client.from('posts').select('created_at').gte('created_at', sinceIso),
      this.supabase.client.from('verifications').select('created_at, status').gte('created_at', sinceIso),
    ]);

    const bucketByDay = (rows: { created_at: string }[]) => {
      const buckets: Record<string, number> = {};
      for (const r of rows) {
        const day = r.created_at.slice(0, 10);
        buckets[day] = (buckets[day] ?? 0) + 1;
      }
      return buckets;
    };

    return {
      success: true,
      last30Days: {
        signupsByDay: bucketByDay(signups.data ?? []),
        postsByDay: bucketByDay(posts.data ?? []),
        verificationsSubmittedByDay: bucketByDay(verifications.data ?? []),
        verificationsApproved: (verifications.data ?? []).filter((v: any) => v.status === 'approved').length,
      },
    };
  }

  // ---------- Students ----------

  @Get('students')
  async getStudents(
    @Headers('authorization') authHeader: string,
    @Query('search') search?: string,
    @Query('filter') filter?: string, // 'verified' | 'unverified' | 'suspended'
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '25',
  ) {
    await this.getAdminFromToken(authHeader);

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const size = Math.min(100, Math.max(1, parseInt(pageSize, 10) || 25));
    const from = (pageNum - 1) * size;
    const to = from + size - 1;

    let query = this.supabase.client
      .from('profiles')
      .select('id, full_name, username, avatar_url, is_verified, is_suspended, role, universities(name)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to);

    if (search) query = query.or(`full_name.ilike.%${search}%,username.ilike.%${search}%`);
    if (filter === 'verified') query = query.eq('is_verified', true);
    if (filter === 'unverified') query = query.eq('is_verified', false);
    if (filter === 'suspended') query = query.eq('is_suspended', true);

    const { data, error, count } = await query;
    if (error) return { success: false, error: error.message };

    return { success: true, students: data, total: count ?? 0, page: pageNum, pageSize: size };
  }

  @Patch('students/:id/suspend')
  async suspendStudent(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { confirm: boolean; suspended: boolean },
  ) {
    const admin = await this.getAdminFromToken(authHeader);
    if (!body.confirm) {
      return { success: false, error: 'Confirmation required' };
    }

    const { error } = await this.supabase.client
      .from('profiles')
      .update({ is_suspended: body.suspended })
      .eq('id', id);

    if (error) return { success: false, error: error.message };

    await this.logAction(admin.id, body.suspended ? 'suspend_student' : 'unsuspend_student', 'profile', id);
    return { success: true };
  }

  // ---------- Content moderation ----------

  private async removeContent(
    admin: any,
    table: string,
    id: string,
    body: { confirm: boolean; reason: string },
    authorField: string,
    notifyType: string,
  ) {
    if (!body.confirm) return { success: false, error: 'Confirmation required' };
    if (!body.reason?.trim()) return { success: false, error: 'A reason is required' };

    const updateFields =
      table === 'listings' || table === 'services'
        ? { status: 'removed' }
        : table === 'events'
        ? { status: 'removed' }
        : { is_removed: true, removed_reason: body.reason.trim() };

    const { data: updated, error } = await this.supabase.client
      .from(table)
      .update(updateFields)
      .eq('id', id)
      .select(`id, ${authorField}`)
      .single();

    if (error) return { success: false, error: error.message };

    await this.logAction(admin.id, `remove_${table}`, table, id, { reason: body.reason.trim() });

    const authorId = (updated as any)?.[authorField];
    if (authorId) {
      await this.notifications.create(
        authorId,
        notifyType,
        'Content removed',
        `Your content was removed by a moderator: ${body.reason.trim()}`,
        { table, id },
      );
    }

    return { success: true };
  }

  @Patch('posts/:id/remove')
  async removePost(@Headers('authorization') authHeader: string, @Param('id') id: string, @Body() body: { confirm: boolean; reason: string }) {
    const admin = await this.getAdminFromToken(authHeader);
    return this.removeContent(admin, 'posts', id, body, 'author_id', 'content_removed');
  }

  @Patch('anonymous/:id/remove')
  async removeAnonymousPost(@Headers('authorization') authHeader: string, @Param('id') id: string, @Body() body: { confirm: boolean; reason: string }) {
    const admin = await this.getAdminFromToken(authHeader);
    // Anonymous posts intentionally do NOT resolve to a notifiable author_id here —
    // doing so would require joining anonymous_profiles -> user_id, which defeats the
    // identity-separation guarantee documented in the handoff (Phase 8). We log the
    // moderation action but do not notify, by design.
    if (!body.confirm) return { success: false, error: 'Confirmation required' };
    if (!body.reason?.trim()) return { success: false, error: 'A reason is required' };

    const { error } = await this.supabase.client
      .from('anonymous_posts')
      .update({ is_removed: true, removed_reason: body.reason.trim() })
      .eq('id', id);

    if (error) return { success: false, error: error.message };
    await this.logAction(admin.id, 'remove_anonymous_post', 'anonymous_posts', id, { reason: body.reason.trim() });
    return { success: true };
  }

  @Patch('listings/:id/remove')
  async removeListing(@Headers('authorization') authHeader: string, @Param('id') id: string, @Body() body: { confirm: boolean; reason: string }) {
    const admin = await this.getAdminFromToken(authHeader);
    return this.removeContent(admin, 'listings', id, body, 'seller_id', 'listing_removed');
  }

  @Patch('services/:id/remove')
  async removeService(@Headers('authorization') authHeader: string, @Param('id') id: string, @Body() body: { confirm: boolean; reason: string }) {
    const admin = await this.getAdminFromToken(authHeader);
    return this.removeContent(admin, 'services', id, body, 'provider_id', 'service_removed');
  }

  @Patch('events/:id/remove')
  async removeEvent(@Headers('authorization') authHeader: string, @Param('id') id: string, @Body() body: { confirm: boolean; reason: string }) {
    const admin = await this.getAdminFromToken(authHeader);
    return this.removeContent(admin, 'events', id, body, 'organizer_id', 'event_removed');
  }

  // ---------- Universities ----------

  @Get('universities')
  async getUniversities(@Headers('authorization') authHeader: string) {
    await this.getAdminFromToken(authHeader);
    const { data, error } = await this.supabase.client.from('universities').select('*').order('name');
    if (error) return { success: false, error: error.message };
    return { success: true, universities: data };
  }

  @Post('universities')
  async createUniversity(
    @Headers('authorization') authHeader: string,
    @Body() body: { name: string; shortName?: string; city?: string; country?: string; ownershipType?: string },
  ) {
    const admin = await this.getAdminFromToken(authHeader, 'university_admin');
    if (!body.name?.trim()) return { success: false, error: 'Name is required' };

    const { data, error } = await this.supabase.client
      .from('universities')
      .insert({
        name: body.name.trim(),
        short_name: body.shortName ?? null,
        city: body.city ?? null,
        country: body.country ?? 'Nigeria',
        ownership_type: body.ownershipType ?? 'private',
      })
      .select()
      .single();

    if (error) return { success: false, error: error.message };
    await this.logAction(admin.id, 'create_university', 'universities', data.id);
    return { success: true, university: data };
  }

  @Patch('universities/:id')
  async updateUniversity(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: Record<string, any>,
  ) {
    const admin = await this.getAdminFromToken(authHeader, 'university_admin');
    const { error } = await this.supabase.client.from('universities').update(body).eq('id', id);
    if (error) return { success: false, error: error.message };
    await this.logAction(admin.id, 'update_university', 'universities', id, body);
    return { success: true };
  }

  // ---------- Announcements ----------

  @Post('announcements')
  async createAnnouncement(
    @Headers('authorization') authHeader: string,
    @Body() body: { title: string; body: string; universityId?: string; isGlobal?: boolean },
  ) {
    const admin = await this.getAdminFromToken(authHeader);
    if (!body.title?.trim() || !body.body?.trim()) {
      return { success: false, error: 'Title and body are required' };
    }

    const { data, error } = await this.supabase.client
      .from('announcements')
      .insert({
        title: body.title.trim(),
        body: body.body.trim(),
        university_id: body.isGlobal ? null : body.universityId ?? null,
        is_global: !!body.isGlobal,
        sent_by: admin.id,
      })
      .select()
      .single();

    if (error) return { success: false, error: error.message };
    await this.logAction(admin.id, 'create_announcement', 'announcements', data.id);
    return { success: true, announcement: data };
  }

  // ---------- Reports queue ----------

  @Get('reports')
  async getReports(
    @Headers('authorization') authHeader: string,
    @Query('type') type?: string,
    @Query('status') status = 'pending',
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '25',
  ) {
    await this.getAdminFromToken(authHeader);

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const size = Math.min(100, Math.max(1, parseInt(pageSize, 10) || 25));
    const from = (pageNum - 1) * size;
    const to = from + size - 1;

    let query = this.supabase.client
      .from('reports')
      .select('*, reporter:profiles!reports_reported_by_fkey(full_name, username)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to);

    if (type) query = query.eq('target_type', type);
    if (status) query = query.eq('status', status);

    const { data, error, count } = await query;
    if (error) return { success: false, error: error.message };

    // Anonymous-post reports must never expose the real identity behind the
    // anonymous account through routine moderation browsing — this holds for
    // every admin role, including super_admin. There is no passive path to this
    // data by design; the only way to learn it is the explicit, audited
    // POST /admin/reports/:id/reveal-identity endpoint, which requires a stated
    // reason and is logged. Do not "fix" this by re-adding reported_user_id here.
    const redacted = (data ?? []).map((r: any) =>
      r.target_type === 'anonymous_post' ? { ...r, reported_user_id: null } : r,
    );

    return { success: true, reports: redacted, total: count ?? 0, page: pageNum, pageSize: size };
  }

  @Post('reports/:id/reveal-identity')
  async revealAnonymousIdentity(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { reason: string },
  ) {
    const admin = await this.getAdminFromToken(authHeader, 'super_admin');

    if (!body.reason?.trim()) {
      return { success: false, error: 'A reason is required to reveal an identity' };
    }

    const { data: report, error: reportError } = await this.supabase.client
      .from('reports')
      .select('id, target_type, target_id')
      .eq('id', id)
      .single();

    if (reportError || !report) {
      return { success: false, error: 'Report not found' };
    }
    if (report.target_type !== 'anonymous_post') {
      return { success: false, error: 'This endpoint only applies to anonymous post reports' };
    }

    // Resolved on demand, never persisted — this is the only place in the
    // codebase where an anonymous post's real author is looked up for
    // moderation purposes, and every call is logged with a reason.
    const { data: post } = await this.supabase.client
      .from('anonymous_posts')
      .select('anonymous_profile_id')
      .eq('id', report.target_id)
      .single();

    if (!post?.anonymous_profile_id) {
      return { success: false, error: 'Could not resolve the underlying anonymous post' };
    }

    const { data: anonymousProfile } = await this.supabase.client
      .from('anonymous_profiles')
      .select('user_id')
      .eq('id', post.anonymous_profile_id)
      .single();

    if (!anonymousProfile?.user_id) {
      return { success: false, error: 'Could not resolve the real identity' };
    }

    const { data: identity } = await this.supabase.client
      .from('profiles')
      .select('id, full_name, username, avatar_url')
      .eq('id', anonymousProfile.user_id)
      .single();

    await this.logAction(admin.id, 'reveal_anonymous_identity', 'anonymous_post', report.target_id, {
      reason: body.reason.trim(),
      revealed_to: admin.id,
      reportId: id,
    });

    return { success: true, identity };
  }

  @Patch('reports/:id')
  async resolveReport(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { status: string; resolutionNote?: string },
  ) {
    const admin = await this.getAdminFromToken(authHeader);
    if (!['reviewed', 'dismissed'].includes(body.status)) {
      return { success: false, error: 'Invalid status' };
    }

    const { data: updated, error } = await this.supabase.client
      .from('reports')
      .update({
        status: body.status,
        resolution_note: body.resolutionNote ?? null,
        resolved_by: admin.id,
        resolved_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select();

    if (error) return { success: false, error: error.message };
    if (!updated || updated.length === 0) return { success: false, error: 'Report not found' };

    await this.logAction(admin.id, 'resolve_report', 'reports', id, body);
    return { success: true };
  }

  // ---------- Admin management (super_admin only) ----------

  @Get('admins')
  async getAdmins(@Headers('authorization') authHeader: string) {
    await this.getAdminFromToken(authHeader, 'super_admin');
    const { data, error } = await this.supabase.client
      .from('profiles')
      .select('id, full_name, username, role')
      .neq('role', 'student');
    if (error) return { success: false, error: error.message };
    return { success: true, admins: data };
  }

  @Patch('admins/:id')
  async updateAdminRole(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { role: string; confirm: boolean },
  ) {
    const admin = await this.getAdminFromToken(authHeader, 'super_admin');
    if (!body.confirm) return { success: false, error: 'Confirmation required' };
    if (!['student', 'moderator', 'university_admin', 'super_admin'].includes(body.role)) {
      return { success: false, error: 'Invalid role' };
    }

    const { error } = await this.supabase.client.from('profiles').update({ role: body.role }).eq('id', id);
    if (error) return { success: false, error: error.message };

    await this.logAction(admin.id, 'change_admin_role', 'profiles', id, { newRole: body.role });
    return { success: true };
  }

  // ---------- Verifications (existing, unchanged behavior) ----------

  @Get('verifications/pending')
  async getPending(@Headers('authorization') authHeader: string) {
    await this.getAdminFromToken(authHeader);
    const { data, error } = await this.supabase.client
      .from('verifications')
      .select('*, universities(name)')
      .eq('status', 'pending')
      .order('created_at', { ascending: true });
    if (error) return { success: false, error: error.message };
    return { success: true, verifications: data };
  }

  @Get('verifications/:id/document-url')
  async getDocumentUrl(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    await this.getAdminFromToken(authHeader);
    const { data: verification, error: fetchError } = await this.supabase.client
      .from('verifications')
      .select('document_path')
      .eq('id', id)
      .single();
    if (fetchError || !verification) return { success: false, error: 'Verification not found' };

    const { data, error } = await this.supabase.client.storage
      .from('verification-docs')
      .createSignedUrl(verification.document_path, 300);
    if (error) return { success: false, error: error.message };
    return { success: true, url: data.signedUrl };
  }

  @Patch('verifications/:id/approve')
  async approve(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const admin = await this.getAdminFromToken(authHeader);
    const { data: verification, error: fetchError } = await this.supabase.client
      .from('verifications').select('user_id').eq('id', id).single();
    if (fetchError || !verification) return { success: false, error: 'Verification not found' };

    const { data: updated, error } = await this.supabase.client
      .from('verifications')
      .update({ status: 'approved', reviewed_by: admin.id, reviewed_at: new Date().toISOString() })
      .eq('id', id).select();
    if (error) return { success: false, error: error.message };
    if (!updated || updated.length === 0) return { success: false, error: 'No verification record was updated' };

    await this.supabase.client.from('profiles').update({ is_verified: true }).eq('id', verification.user_id);
    await this.notifications.create(verification.user_id, 'verification_approved', 'You are now verified! ✅', 'Your student status has been confirmed.');
    await this.logAction(admin.id, 'approve_verification', 'verifications', id);
    return { success: true };
  }

  @Patch('verifications/:id/reject')
  async reject(@Headers('authorization') authHeader: string, @Param('id') id: string, @Body() body: { reason: string }) {
    const admin = await this.getAdminFromToken(authHeader);
    const { data: updated, error } = await this.supabase.client
      .from('verifications')
      .update({ status: 'rejected', rejection_reason: body.reason, reviewed_by: admin.id, reviewed_at: new Date().toISOString() })
      .eq('id', id).select();
    if (error) return { success: false, error: error.message };
    if (!updated || updated.length === 0) return { success: false, error: 'No verification record was updated' };

    await this.notifications.create(updated[0].user_id, 'verification_rejected', 'Verification needs another look', body.reason);
    await this.logAction(admin.id, 'reject_verification', 'verifications', id, { reason: body.reason });
    return { success: true };
  }
}