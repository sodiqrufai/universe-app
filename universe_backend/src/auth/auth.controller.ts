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
      // Trust Supabase's own error for a genuine duplicate-signup rejection
      // (this is what fires when email confirmation is off, the case that's
      // live on this project today) rather than inferring it from an absent
      // session, which is ambiguous and wrong for a real new user awaiting
      // confirmation.
      return { success: false, error: error.message };
    }

    if (!data.user) {
      return { success: false, error: 'Registration failed unexpectedly' };
    }

    // A profile row must exist the instant the auth account exists, full stop
    // -- this can no longer be skipped by any branch below. If this insert
    // hits a primary-key conflict (the ambiguous existing-user case Supabase
    // itself can return with no error and no session, as an anti-enumeration
    // measure when email confirmation is ON), it fails silently here, which is
    // correct: that user already has a profile row from their original signup.
    await this.supabase.client.from('profiles').insert({
      id: data.user.id,
      full_name: body.fullName?.trim() || null,
    });

    if (!data.session) {
      // No error AND no session = confirmation-pending, not a failure.
      // NOTE: if email confirmation is ever turned ON for this project,
      // Supabase can also return exactly this shape for a duplicate-email
      // signup attempt, as a deliberate anti-enumeration design choice on
      // their end -- that specific ambiguity isn't fully resolvable from this
      // side of the API. Today, with confirmation OFF, this branch should only
      // ever mean "awaiting confirmation."
      return { success: true, needsConfirmation: true, userId: data.user.id };
    }

    return {
      success: true,
      needsConfirmation: false,
      userId: data.user.id,
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