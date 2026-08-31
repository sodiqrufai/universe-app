import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient } from '@supabase/supabase-js';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly config: ConfigService,
  ) {}

  private getAuthClient() {
    return createClient(
      this.config.get<string>('SUPABASE_URL')!,
      this.config.get<string>('SUPABASE_ANON_KEY')!,
    );
  }

  @Get('check-username')
  async checkUsername(@Query('u') username?: string) {
    const value = username?.trim();
    if (!value || value.length < 3 || value.length > 20) {
      return { available: false, error: 'Username must be 3-20 characters' };
    }
    if (!/^[a-zA-Z0-9_]+$/.test(value)) {
      return { available: false, error: 'Only letters, numbers, and underscores allowed' };
    }

    const { data } = await this.supabase.client
      .from('profiles')
      .select('id')
      .eq('username_lower', value.toLowerCase())
      .maybeSingle();

    return { available: !data };
  }

  @Post('register')
  async register(@Body() body: { email: string; password: string; fullName?: string }) {
    const { data, error } = await this.getAuthClient().auth.signUp({
      email: body.email,
      password: body.password,
    });

    if (error) {
      return { success: false, error: error.message };
    }

    if (!data.session) {
      return { success: false, error: 'This email is already registered. Please log in instead.' };
    }

    await this.supabase.client.from('profiles').insert({
      id: data.user!.id,
      full_name: body.fullName?.trim() || null,
    });

    return {
      success: true,
      userId: data.user?.id,
      accessToken: data.session.access_token,
      refreshToken: data.session.refresh_token,
    };
  }

  @Post('login')
  async login(@Body() body: { email: string; password: string }) {
    const { data, error } = await this.getAuthClient().auth.signInWithPassword({
      email: body.email,
      password: body.password,
    });

    if (error) {
      return { success: false, error: error.message };
    }

    return {
      success: true,
      userId: data.user?.id,
      accessToken: data.session?.access_token,
      refreshToken: data.session?.refresh_token,
    };
  }

  @Post('refresh')
  async refresh(@Body() body: { refreshToken: string }) {
    const { data, error } = await this.getAuthClient().auth.refreshSession({
      refresh_token: body.refreshToken,
    });

    if (error || !data.session) {
      return { success: false, error: error?.message ?? 'Refresh failed' };
    }

    return {
      success: true,
      accessToken: data.session.access_token,
      refreshToken: data.session.refresh_token,
    };
  }

  @Post('reset-password')
  async resetPassword(@Body() body: { email: string }) {
    const { error } = await this.getAuthClient().auth.resetPasswordForEmail(body.email);

    if (error) {
      return { success: false, error: error.message };
    }
    return { success: true };
  }
}