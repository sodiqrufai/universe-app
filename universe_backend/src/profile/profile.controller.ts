import { Body, Controller, Get, Headers, Param, Patch, Post, UnauthorizedException, UploadedFile, UseInterceptors } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient } from '@supabase/supabase-js';
import { SupabaseService } from '../supabase/supabase.service';
import { FileInterceptor } from '@nestjs/platform-express';
import { Delete } from '@nestjs/common';


@Controller('profile')
export class ProfileController {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly config: ConfigService,
  ) {}

  private getAuthClient() {
    // Isolated, short-lived client for anything that touches auth.signIn/signUp/
    // updateUser -- see the handoff doc's "shared session bug" lesson. Never reuse
    // this.supabase.client (the service-role singleton) for auth flows.
    return createClient(
      this.config.get<string>('SUPABASE_URL')!,
      this.config.get<string>('SUPABASE_ANON_KEY')!,
    );
  }

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

  @Post('change-password')
  async changePassword(
    @Headers('authorization') authHeader: string,
    @Body() body: { currentPassword: string; newPassword: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.currentPassword || !body.newPassword) {
      return { success: false, error: 'Current and new password are required' };
    }
    if (body.newPassword.length < 6) {
      return { success: false, error: 'New password must be at least 6 characters' };
    }

    const { data: userData } = await this.supabase.client.auth.admin.getUserById(user.id);
    const email = userData?.user?.email;
    if (!email) {
      return { success: false, error: 'Could not resolve account email' };
    }

    // Verify the current password by attempting a real sign-in with it, on an
    // isolated ephemeral client -- never the shared service-role singleton.
    const authClient = this.getAuthClient();
    const { error: verifyError } = await authClient.auth.signInWithPassword({
      email,
      password: body.currentPassword,
    });

    if (verifyError) {
      return { success: false, error: 'Current password is incorrect' };
    }

    // Password updates must be applied via the service-role admin API, keyed by
    // user id, rather than authClient.auth.updateUser -- that method operates on
    // whatever session is currently active on the client, and mixing it with the
    // signIn call above on the same client risks the exact session-bleed bug
    // documented in the handoff. Using supabase.client.auth.admin.updateUserById
    // sidesteps sessions entirely.
    const { error: updateError } = await this.supabase.client.auth.admin.updateUserById(user.id, {
      password: body.newPassword,
    });

    if (updateError) {
      return { success: false, error: updateError.message };
    }
    return { success: true };
  }

  @Patch('update')
  async updateProfile(
    @Headers('authorization') authHeader: string,
    @Body() body: {
      universityId?: string;
      facultyId?: string;
      departmentId?: string;
      level?: string;
      fullName?: string;
      username?: string;
      bio?: string;
    },
  ) {
    const user = await this.getUserFromToken(authHeader);

    const updates: Record<string, any> = { updated_at: new Date().toISOString() };
    if (body.universityId) updates.university_id = body.universityId;
    if (body.facultyId) updates.faculty_id = body.facultyId;
    if (body.departmentId) updates.department_id = body.departmentId;
    if (body.level) updates.level = body.level;
    if (body.fullName !== undefined) updates.full_name = body.fullName;
    if (body.username !== undefined) updates.username = body.username;
    if (body.bio !== undefined) updates.bio = body.bio;

    const { error } = await this.supabase.client
      .from('profiles')
      .upsert({ id: user.id, ...updates });

    if (error) {
      return { success: false, error: error.message };
    }
    return { success: true };
  }

  @Patch('complete-setup')
  async completeSetup(
    @Headers('authorization') authHeader: string,
    @Body() body: { username: string; avatarUrl?: string; bio?: string; level: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.username?.trim()) {
      return { success: false, error: 'Username is required' };
    }
    if (!/^[a-zA-Z0-9_]{3,20}$/.test(body.username.trim())) {
      return { success: false, error: 'Username must be 3-20 characters, letters/numbers/underscores only' };
    }
    if (!body.level || !['100L', '200L', '300L', '400L', '500L', 'Postgraduate'].includes(body.level)) {
      return { success: false, error: 'A valid level is required' };
    }

    // Single batched write so a student abandoning the review screen midway
    // never leaves a half-saved profile (partial username with no level set,
    // etc.) -- everything commits together or nothing does.
    const updates: Record<string, any> = {
      username: body.username.trim(),
      level: body.level,
      updated_at: new Date().toISOString(),
    };
    if (body.avatarUrl !== undefined) updates.avatar_url = body.avatarUrl;
    if (body.bio !== undefined) updates.bio = body.bio.trim();

    const { error } = await this.supabase.client
      .from('profiles')
      .update(updates)
      .eq('id', user.id);

    if (error) {
      if (error.code === '23505') {
        return { success: false, error: 'That username is already taken' };
      }
      return { success: false, error: error.message };
    }
    return { success: true };
  }

  @Post(':id/follow')
  async followUser(@Headers('authorization') authHeader: string, @Param('id') targetId: string) {
    const user = await this.getUserFromToken(authHeader);

    if (targetId === user.id) {
      return { success: false, error: 'Cannot follow yourself' };
    }

    const { error } = await this.supabase.client
      .from('follows')
      .insert({ follower_id: user.id, followed_id: targetId });

    if (error) {
      if (error.code === '23505') return { success: true }; // already following, treat as success
      return { success: false, error: error.message };
    }
    return { success: true };
  }

  @Delete(':id/follow')
  async unfollowUser(@Headers('authorization') authHeader: string, @Param('id') targetId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('follows')
      .delete()
      .eq('follower_id', user.id)
      .eq('followed_id', targetId);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Get('me')
  async getMyProfile(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('profiles')
      .select('*, universities(name), faculties(name), departments(name)')
      .eq('id', user.id)
      .single();

    if (error) {
      return { success: false, error: error.message };
    }
    return { success: true, profile: data };
  }
  
  @Post('avatar')
  @UseInterceptors(FileInterceptor('file'))
  async uploadAvatar(
    @Headers('authorization') authHeader: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!file) {
      return { success: false, error: 'No file provided' };
    }

    const filePath = `${user.id}/avatar.jpg`;

    const { error: uploadError } = await this.supabase.client.storage
      .from('avatars')
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: true,
      });

    if (uploadError) {
      return { success: false, error: uploadError.message };
    }

    const { data: urlData } = this.supabase.client.storage
      .from('avatars')
      .getPublicUrl(filePath);

    await this.supabase.client
      .from('profiles')
      .upsert({ id: user.id, avatar_url: urlData.publicUrl, updated_at: new Date().toISOString() });

    return { success: true, avatarUrl: urlData.publicUrl };
  }

  @Get('settings')
  async getSettings(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('user_settings')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle();

    if (error) return { success: false, error: error.message };

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('locale')
      .eq('id', user.id)
      .single();

    return {
      success: true,
      settings: data ?? {
        profile_visibility: 'everyone',
        allow_messages: true,
        notify_chat: true,
        notify_marketplace: true,
        notify_events: true,
        notify_community: true,
      },
      locale: profile?.locale ?? 'en',
    };
  }

  @Patch('locale')
  async updateLocale(@Headers('authorization') authHeader: string, @Body() body: { locale: string }) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.locale?.trim()) {
      return { success: false, error: 'Locale is required' };
    }

    const { error } = await this.supabase.client
      .from('profiles')
      .update({ locale: body.locale.trim() })
      .eq('id', user.id);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Patch('settings')
  async updateSettings(
    @Headers('authorization') authHeader: string,
    @Body() body: Record<string, any>,
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('user_settings')
      .upsert({ user_id: user.id, ...body, updated_at: new Date().toISOString() });

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Get('my-posts')
  async getMyPosts(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('posts')
      .select('*, profiles(full_name, username, avatar_url, is_verified)')
      .eq('author_id', user.id)
      .order('created_at', { ascending: false });

    if (error) return { success: false, error: error.message };
    return { success: true, posts: data };
  }

  @Get('blocked-users')
  async getBlockedUsers(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('blocked_users')
      .select('id, blocked_id, profiles!blocked_users_blocked_id_fkey(full_name, avatar_url)')
      .eq('blocker_id', user.id);

    if (error) return { success: false, error: error.message };
    return { success: true, blocked: data };
  }

  @Delete('account')
  async deleteAccount(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client.auth.admin.deleteUser(user.id);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }
}