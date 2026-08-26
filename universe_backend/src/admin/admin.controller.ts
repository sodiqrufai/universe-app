import { Body, Controller, Get, Headers, Param, Patch, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { NotificationsService } from '../notifications/notifications.service';

@Controller('admin')
export class AdminController {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly notifications: NotificationsService,
  ) {}

  private async getAdminFromToken(authHeader?: string) {
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
      .select('is_admin')
      .eq('id', data.user.id)
      .single();

    if (!profile?.is_admin) {
      throw new ForbiddenException('Admin access required');
    }

    return data.user;
  }

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
  async getDocumentUrl(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
  ) {
    await this.getAdminFromToken(authHeader);

    const { data: verification, error: fetchError } = await this.supabase.client
      .from('verifications')
      .select('document_path')
      .eq('id', id)
      .single();

    if (fetchError || !verification) {
      return { success: false, error: 'Verification not found' };
    }

    const { data, error } = await this.supabase.client.storage
      .from('verification-docs')
      .createSignedUrl(verification.document_path, 300);

    if (error) return { success: false, error: error.message };
    return { success: true, url: data.signedUrl };
  }

  @Patch('verifications/:id/approve')
  async approve(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
  ) {
    const admin = await this.getAdminFromToken(authHeader);

    const { data: verification, error: fetchError } = await this.supabase.client
      .from('verifications')
      .select('user_id')
      .eq('id', id)
      .single();

    if (fetchError || !verification) {
      return { success: false, error: 'Verification not found' };
    }

    const { data: updated, error } = await this.supabase.client
      .from('verifications')
      .update({
        status: 'approved',
        reviewed_by: admin.id,
        reviewed_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select();

    if (error) return { success: false, error: error.message };
    if (!updated || updated.length === 0) {
      return { success: false, error: 'No verification record was updated — check the ID' };
    }

    await this.supabase.client
      .from('profiles')
      .update({ is_verified: true })
      .eq('id', verification.user_id);

    await this.notifications.create(
      verification.user_id,
      'verification_approved',
      'You are now verified! ✅',
      'Your student status has been confirmed.',
    );

    return { success: true };
  }

  @Patch('verifications/:id/reject')
  async reject(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { reason: string },
  ) {
    const admin = await this.getAdminFromToken(authHeader);

    const { data: updated, error } = await this.supabase.client
      .from('verifications')
      .update({
        status: 'rejected',
        rejection_reason: body.reason,
        reviewed_by: admin.id,
        reviewed_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select();

    if (error) return { success: false, error: error.message };
    if (!updated || updated.length === 0) {
      return { success: false, error: 'No verification record was updated — check the ID' };
    }

    await this.notifications.create(
      updated[0].user_id,
      'verification_rejected',
      'Verification needs another look',
      body.reason,
    );

    return { success: true };
  }
}