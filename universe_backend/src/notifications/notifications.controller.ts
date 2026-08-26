import { Controller, Get, Headers, Param, Patch, UnauthorizedException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('notifications')
export class NotificationsController {
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

  @Get()
  async getNotifications(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('notifications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(50);

    if (error) return { success: false, error: error.message };

    const unreadCount = (data ?? []).filter((n) => !n.is_read).length;
    return { success: true, notifications: data, unreadCount };
  }

  @Patch(':id/read')
  async markRead(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('notifications')
      .update({ is_read: true })
      .eq('id', id)
      .eq('user_id', user.id);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Patch('read-all')
  async markAllRead(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', user.id)
      .eq('is_read', false);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }
}