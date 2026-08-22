import { Body, Controller, Delete, Get, Headers, Param, Post, UnauthorizedException, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('posts')
export class PostsController {
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

  @Post()
  @UseInterceptors(FileInterceptor('file'))
  async createPost(
    @Headers('authorization') authHeader: string,
    @UploadedFile() file: any,
    @Body() body: { content: string; visibility: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.content?.trim()) {
      return { success: false, error: 'Post content cannot be empty' };
    }

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    let imageUrl: string | null = null;
    if (file) {
      const filePath = `${user.id}/${Date.now()}.jpg`;
      const { error: uploadError } = await this.supabase.client.storage
        .from('post-media')
        .upload(filePath, file.buffer, { contentType: file.mimetype });
      if (uploadError) {
        console.error('Post media upload error:', uploadError);
        return { success: false, error: uploadError.message };
      }
      const { data: urlData } = this.supabase.client.storage.from('post-media').getPublicUrl(filePath);
      imageUrl = urlData.publicUrl;
    }

    const visibility = body.visibility === 'global' ? 'global' : 'university';

    const { data, error } = await this.supabase.client
      .from('posts')
      .insert({
        author_id: user.id,
        content: body.content.trim(),
        image_url: imageUrl,
        visibility,
        university_id: profile?.university_id ?? null,
      })
      .select()
      .single();

    if (error) {
      console.error('Create post error:', error);
      return { success: false, error: error.message };
    }
    return { success: true, post: data };
  }

  @Get('feed')
  async getFeed(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    const universityId = profile?.university_id;

    let query = this.supabase.client
      .from('posts')
      .select('*, profiles(full_name, username, avatar_url, is_verified)')
      .order('created_at', { ascending: false });

    if (universityId) {
      query = query.or(`visibility.eq.global,and(visibility.eq.university,university_id.eq.${universityId})`);
    } else {
      query = query.eq('visibility', 'global');
    }

    const { data, error } = await query;

    if (error) {
      console.error('Feed query error:', error);
      return { success: false, error: error.message };
    }

    const postIds = (data ?? []).map((p) => p.id);
    let reactionCounts: Record<string, number> = {};
    let userReactions = new Set<string>();
    let commentCounts: Record<string, number> = {};

    if (postIds.length > 0) {
      const { data: reactions } = await this.supabase.client
        .from('reactions')
        .select('post_id, user_id')
        .in('post_id', postIds);

      reactions?.forEach((r) => {
        reactionCounts[r.post_id] = (reactionCounts[r.post_id] ?? 0) + 1;
        if (r.user_id === user.id) userReactions.add(r.post_id);
      });

      const { data: comments } = await this.supabase.client
        .from('comments')
        .select('post_id')
        .in('post_id', postIds);

      comments?.forEach((c) => {
        commentCounts[c.post_id] = (commentCounts[c.post_id] ?? 0) + 1;
      });
    }

    const enriched = (data ?? []).map((p) => ({
      ...p,
      reactionCount: reactionCounts[p.id] ?? 0,
      hasReacted: userReactions.has(p.id),
      commentCount: commentCounts[p.id] ?? 0,
    }));

    return { success: true, posts: enriched };
  }

  @Delete(':id')
  async deletePost(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: deleted, error } = await this.supabase.client
      .from('posts')
      .delete()
      .eq('id', id)
      .eq('author_id', user.id)
      .select();

    if (error) return { success: false, error: error.message };
    if (!deleted || deleted.length === 0) {
      return { success: false, error: 'Post not found or not yours to delete' };
    }
    return { success: true };
  }

  @Post(':id/react')
  async toggleReaction(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: existing } = await this.supabase.client
      .from('reactions')
      .select('id')
      .eq('post_id', id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existing) {
      await this.supabase.client.from('reactions').delete().eq('id', existing.id);
      return { success: true, reacted: false };
    } else {
      await this.supabase.client.from('reactions').insert({ post_id: id, user_id: user.id });
      return { success: true, reacted: true };
    }
  }

  @Get(':id/comments')
  async getComments(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('comments')
      .select('*, profiles(full_name, username, avatar_url)')
      .eq('post_id', id)
      .order('created_at', { ascending: true });

    if (error) return { success: false, error: error.message };
    return { success: true, comments: data };
  }

  @Post(':id/comments')
  async addComment(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { content: string; parentCommentId?: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.content?.trim()) {
      return { success: false, error: 'Comment cannot be empty' };
    }

    const { data, error } = await this.supabase.client
      .from('comments')
      .insert({
        post_id: id,
        author_id: user.id,
        content: body.content.trim(),
        parent_comment_id: body.parentCommentId ?? null,
      })
      .select('*, profiles(full_name, username, avatar_url)')
      .single();

    if (error) return { success: false, error: error.message };
    return { success: true, comment: data };
  }

  @Post(':id/report')
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
      .from('reports')
      .insert({ post_id: id, reported_by: user.id, reason: body.reason.trim() });

    if (error) return { success: false, error: error.message };
    return { success: true };
  }
}