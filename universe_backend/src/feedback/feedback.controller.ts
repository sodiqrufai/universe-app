import { Body, Controller, Headers, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { SupabaseService } from '../supabase/supabase.service';

export class FeedbackDto {
  @IsString()
  @MinLength(3, { message: 'Please write a little more so we can understand.' })
  @MaxLength(2000, { message: 'Feedback is too long (max 2000 characters).' })
  message!: string;

  @IsIn(['bug', 'idea', 'other'], { message: 'Category must be bug, idea or other.' })
  category!: 'bug' | 'idea' | 'other';

  @IsOptional() @IsString() @MaxLength(120) screen?: string;
  @IsOptional() @IsString() @MaxLength(40) appVersion?: string;
  @IsOptional() @IsString() @MaxLength(40) platform?: string;
}

@Controller('feedback')
export class FeedbackController {
  constructor(private readonly supabase: SupabaseService) {}

  // Auth is OPTIONAL: someone locked out of login should still be able to tell us.
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Post()
  async submit(@Headers('authorization') authHeader: string, @Body() body: FeedbackDto) {
    let userId: string | null = null;
    if (authHeader?.startsWith('Bearer ')) {
      const { data } = await this.supabase.client.auth.getUser(authHeader.slice(7));
      userId = data?.user?.id ?? null;
    }

    const { error } = await this.supabase.client.from('feedback').insert({
      user_id: userId,
      message: body.message.trim(),
      category: body.category,
      screen: body.screen ?? null,
      app_version: body.appVersion ?? null,
      platform: body.platform ?? null,
    });
    if (error) return { success: false, error: 'Could not send your feedback. Please try again.' };
    return { success: true };
  }
}
