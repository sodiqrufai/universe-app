import { Body, Controller, Get, Headers, Param, Patch, Post, UnauthorizedException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('anonymous')
export class AnonymousController {
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

  @Get('profile')
  async getMyAnonymousProfile(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('anonymous_profiles')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle();

    if (error) return { success: false, error: error.message };
    return { success: true, profile: data };
  }

  @Post('profile/check-username')
  async checkUsername(@Body() body: { username: string }) {
    const username = body.username?.trim().toLowerCase();
    if (!username || username.length < 3 || username.length > 20) {
      return { available: false, error: 'Username must be 3-20 characters' };
    }
    if (!/^[a-z0-9_]+$/.test(username)) {
      return { available: false, error: 'Only lowercase letters, numbers, and underscores allowed' };
    }

    const { data } = await this.supabase.client
      .from('anonymous_profiles')
      .select('id')
      .eq('anonymous_username', username)
      .maybeSingle();

    return { available: !data };
  }

  @Post('profile')
  async createAnonymousProfile(
    @Headers('authorization') authHeader: string,
    @Body() body: { username: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    const username = body.username?.trim().toLowerCase();

    if (!username || username.length < 3 || username.length > 20 || !/^[a-z0-9_]+$/.test(username)) {
      return { success: false, error: 'Invalid username' };
    }

    const { data: existingProfile } = await this.supabase.client
      .from('anonymous_profiles')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (existingProfile) {
      return { success: false, error: 'You already have an anonymous identity' };
    }

    const { data, error } = await this.supabase.client
      .from('anonymous_profiles')
      .insert({ user_id: user.id, anonymous_username: username })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        return { success: false, error: 'That username is already taken' };
      }
      return { success: false, error: error.message };
    }

    return { success: true, profile: data };
  }

  @Get('feed')
  async getFeed(@Headers('authorization') authHeader: string) {
    await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('anonymous_posts')
      .select('*, anonymous_profiles(anonymous_username)')
      .order('created_at', { ascending: false });

    if (error) return { success: false, error: error.message };
    return { success: true, posts: data };
  }

  @Post('posts')
  async createPost(
    @Headers('authorization') authHeader: string,
    @Body() body: { content: string; category: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data: anonProfile } = await this.supabase.client
      .from('anonymous_profiles')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!anonProfile) {
      return { success: false, error: 'Create an anonymous identity first' };
    }

    if (!body.content?.trim()) {
      return { success: false, error: 'Post cannot be empty' };
    }

    const category = ['rant', 'advice', 'confession', 'talk'].includes(body.category) ? body.category : 'talk';

    const { data, error } = await this.supabase.client
      .from('anonymous_posts')
      .insert({
        anonymous_profile_id: anonProfile.id,
        content: body.content.trim(),
        category,
      })
      .select('*, anonymous_profiles(anonymous_username)')
      .single();

    if (error) return { success: false, error: error.message };
    return { success: true, post: data };
  }

  @Get('posts/:id/comments')
  async getComments(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
  ) {
    await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('anonymous_comments')
      .select('*, anonymous_profiles(anonymous_username)')
      .eq('anonymous_post_id', id)
      .order('created_at', { ascending: true });

    if (error) return { success: false, error: error.message };
    return { success: true, comments: data };
  }

  @Post('posts/:id/comments')
  async addComment(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { content: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data: anonProfile } = await this.supabase.client
      .from('anonymous_profiles')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!anonProfile) {
      return { success: false, error: 'Create an anonymous identity first' };
    }
    if (!body.content?.trim()) {
      return { success: false, error: 'Comment cannot be empty' };
    }

    const { data, error } = await this.supabase.client
      .from('anonymous_comments')
      .insert({
        anonymous_post_id: id,
        anonymous_profile_id: anonProfile.id,
        content: body.content.trim(),
      })
      .select('*, anonymous_profiles(anonymous_username)')
      .single();

    if (error) return { success: false, error: error.message };
    return { success: true, comment: data };
  }

  @Post('posts/:id/report')
  async reportPost(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { reason: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.reason?.trim()) {
      return { success: false, error: 'Please provide a reason' };
    }

    const { error } = await this.supabase.client
      .from('anonymous_reports')
      .insert({ anonymous_post_id: id, reported_by: user.id, reason: body.reason.trim() });

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Patch('profile')
  async updateAnonymousUsername(
    @Headers('authorization') authHeader: string,
    @Body() body: { username: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    const username = body.username?.trim().toLowerCase();

    if (!username || username.length < 3 || username.length > 20 || !/^[a-z0-9_]+$/.test(username)) {
      return { success: false, error: 'Invalid username' };
    }

    const { data: updated, error } = await this.supabase.client
      .from('anonymous_profiles')
      .update({ anonymous_username: username })
      .eq('user_id', user.id)
      .select();

    if (error) {
      if (error.code === '23505') return { success: false, error: 'That username is already taken' };
      return { success: false, error: error.message };
    }
    if (!updated || updated.length === 0) {
      return { success: false, error: 'No anonymous identity found' };
    }
    return { success: true };
  }
}