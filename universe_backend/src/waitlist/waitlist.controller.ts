import { Body, Controller, Delete, Get, Headers, Post, UnauthorizedException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('waitlist')
export class WaitlistController {
  constructor(private readonly supabase: SupabaseService) {}

  private async getUserFromToken(authHeader?: string) {
    if (!authHeader?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing token');
    }
    const token = authHeader.replace('Bearer ', '');
    const { data, error } = await this.supabase.client.auth.getUser(token);
    if (error || !data.user) {
      throw new UnauthorizedException('Invalid token');
    }
    return data.user;
  }

  @Post('join')
  async joinWaitlist(
    @Headers('authorization') authHeader: string,
    @Body() body: { universityId: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.universityId) {
      return { success: false, error: 'universityId is required' };
    }

    const { data: university } = await this.supabase.client
      .from('universities')
      .select('id, is_pilot')
      .eq('id', body.universityId)
      .single();

    if (!university) {
      return { success: false, error: 'University not found' };
    }
    if (university.is_pilot) {
      return { success: false, error: 'This university is already live -- no need to join a waitlist' };
    }

    // One active entry per user (see the table's unique constraint) --
    // joining again for a different school replaces the previous entry
    // rather than stacking multiple simultaneous waitlist rows.
    const { error } = await this.supabase.client
      .from('waitlist_entries')
      .upsert(
        { user_id: user.id, requested_university_id: body.universityId },
        { onConflict: 'user_id' },
      );

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  // Lets the client distinguish "never picked a university yet" from "picked
  // one, waitlisted, profile.university_id stays null on purpose" -- the
  // resume-flow check splash_screen.dart needs to route correctly.
  @Get('status')
  async getWaitlistStatus(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('waitlist_entries')
      .select('requested_university_id, created_at, universities(name)')
      .eq('user_id', user.id)
      .maybeSingle();

    if (error) return { success: false, error: error.message };
    if (!data) return { success: true, waitlisted: false };

    return {
      success: true,
      waitlisted: true,
      universityId: data.requested_university_id,
      universityName: (data.universities as any)?.name ?? null,
      joinedAt: data.created_at,
    };
  }

  @Delete('leave')
  async leaveWaitlist(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('waitlist_entries')
      .delete()
      .eq('user_id', user.id);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }
}
