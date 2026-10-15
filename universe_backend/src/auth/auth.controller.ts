import { Body, Controller, Get, Header, Post, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { confirmedPage, resetPasswordPage } from './auth.pages';
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

  private publicBaseUrl() {
    return (
      this.config.get<string>('PUBLIC_BASE_URL') ?? 'https://universe-app-w4cc.onrender.com'
    ).replace(/\/$/, '');
  }

  private confirmRedirect() {
    return (
      this.config.get<string>('EMAIL_CONFIRM_REDIRECT_URL') ??
      `${this.publicBaseUrl()}/auth/confirmed`
    );
  }

  private resetRedirect() {
    return (
      this.config.get<string>('PASSWORD_RESET_REDIRECT_URL') ??
      `${this.publicBaseUrl()}/auth/reset-password`
    );
  }

  // Landing page for the link in the "confirm your email" message.
  @Get('confirmed')
  @Header('Content-Type', 'text/html; charset=utf-8')
  confirmed() {
    return confirmedPage();
  }

  // Landing page for the link in the "reset your password" message.
  @Get('reset-password')
  @Header('Content-Type', 'text/html; charset=utf-8')
  resetPasswordLanding() {
    return resetPasswordPage();
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
      email: body.email?.trim().toLowerCase(),
      password: body.password,
      options: { emailRedirectTo: this.confirmRedirect() },
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

    // With email confirmation ON, Supabase answers a signup for an
    // already-registered email with a fake user (no error, no session) and
    // silently keeps the ORIGINAL password. That user's `identities` array
    // is empty. Surface it instead of pretending the signup worked, otherwise
    // the person later logs in with the "new" password and gets "Invalid
    // login credentials".
    if (Array.isArray(data.user.identities) && data.user.identities.length === 0) {
      return {
        success: false,
        error: 'An account with this email already exists. Log in, or use Forgot Password.',
      };
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
      email: body.email?.trim().toLowerCase(),
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

  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Post('reset-password')
  async resetPassword(@Body() body: { email: string }) {
    const { error } = await this.getAuthClient().auth.resetPasswordForEmail(
      body.email?.trim().toLowerCase(),
      { redirectTo: this.resetRedirect() },
    );

    // Always report success for unknown emails (no account enumeration);
    // only surface genuine rate-limit style failures.
    if (error && /rate|too many|seconds/i.test(error.message)) {
      return { success: false, error: 'Please wait a minute before requesting another email.' };
    }
    return { success: true };
  }

  // Called by the reset-password landing page with the recovery token from
  // the emailed link.
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('update-password')
  async updatePassword(@Body() body: { accessToken: string; newPassword: string }) {
    if (!body.accessToken || !body.newPassword || body.newPassword.length < 8) {
      return { success: false, error: 'Password must be at least 8 characters.' };
    }
    const { data, error } = await this.getAuthClient().auth.getUser(body.accessToken);
    if (error || !data.user) {
      return { success: false, error: 'This reset link is invalid or has expired.' };
    }
    const { error: updateError } = await this.supabase.client.auth.admin.updateUserById(
      data.user.id,
      { password: body.newPassword },
    );
    if (updateError) {
      return { success: false, error: updateError.message };
    }
    return { success: true };
  }

  @Throttle({ default: { limit: 3, ttl: 60000 } })
  @Post('resend-confirmation')
  async resendConfirmation(@Body() body: { email: string }) {
    const { error } = await this.getAuthClient().auth.resend({
      type: 'signup',
      email: body.email?.trim().toLowerCase(),
      options: { emailRedirectTo: this.confirmRedirect() },
    });
    if (error && /rate|too many|seconds/i.test(error.message)) {
      return { success: false, error: 'Please wait a minute before requesting another email.' };
    }
    return { success: true };
  }
}
