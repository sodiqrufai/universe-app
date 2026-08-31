import { Controller, Get, Headers, UnauthorizedException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('home')
export class HomeController {
  constructor(private readonly supabase: SupabaseService) {}

  @Get()
  async getHome(@Headers('authorization') authHeader: string) {
    if (!authHeader?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing token');
    }
    const token = authHeader.replace('Bearer ', '');
    const { data: userData, error: userError } = await this.supabase.client.auth.getUser(token);
    if (userError || !userData.user) {
      throw new UnauthorizedException('Invalid token');
    }

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id, full_name, universities(name)')
      .eq('id', userData.user.id)
      .single();

    const universityId = profile?.university_id;

    const { data: announcements, error } = await this.supabase.client
      .from('announcements')
      .select('*')
      .or(`is_global.eq.true,university_id.eq.${universityId}`)
      .order('created_at', { ascending: false });

    if (error) {
      return { success: false, error: error.message };
    }

    // Deliberately not joining announcements.sent_by -> profiles here. Per the
    // team decision on notice identity, students see a fixed "UniVerse
    // Official" attribution regardless of which individual admin sent it --
    // sent_by still exists as a real column for internal accountability
    // (paired with admin_audit_log), it's just never surfaced to end users.
    const brandedAnnouncements = (announcements ?? []).map((a: any) => ({
      ...a,
      senderLabel: 'UniVerse Official',
    }));

    return {
      success: true,
      universityName: (profile?.universities as any)?.name ?? null,
      fullName: profile?.full_name ?? null,
      announcements: brandedAnnouncements,
    };
  }
}