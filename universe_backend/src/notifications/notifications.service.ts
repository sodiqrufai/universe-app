import { Injectable } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Injectable()
export class NotificationsService {
  constructor(private readonly supabase: SupabaseService) {}

  async create(userId: string, type: string, title: string, body?: string, data?: Record<string, any>) {
    await this.supabase.client.from('notifications').insert({
      user_id: userId,
      type,
      title,
      body: body ?? null,
      data: data ?? null,
    });
  }
}