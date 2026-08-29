import { ForbiddenException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

@Injectable()
export class SupabaseService {
  public client: SupabaseClient;

  constructor(private config: ConfigService) {
    this.client = createClient(
      this.config.get<string>('SUPABASE_URL')!,
      this.config.get<string>('SUPABASE_SERVICE_ROLE_KEY')!,
    );
  }

  async assertNotRestricted(userId: string) {
    const { data: profile } = await this.client
      .from('profiles')
      .select('is_suspended, restricted_until')
      .eq('id', userId)
      .single();

    if (profile?.is_suspended) {
      throw new ForbiddenException(
        'Your account has been suspended.',
      );
    }

    if (
      profile?.restricted_until &&
      new Date(profile.restricted_until) > new Date()
    ) {
      throw new ForbiddenException(
        `You're temporarily restricted from posting until ${profile.restricted_until}.`,
      );
    }
  }
}