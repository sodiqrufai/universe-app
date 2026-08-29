import { Body, Controller, Delete, Get, Headers, Param, Post, Query, UnauthorizedException, UploadedFile, UseInterceptors } from '@nestjs/common';
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
    @Body() body: { content: string; visibility: string; tags?: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

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
    // tags sent as a comma-separated string from the client, e.g. "Exam Tips,Hostel Life"
    const tags = body.tags
      ? body.tags.split(',').map((t) => t.trim()).filter(Boolean)
      : null;

    const { data, error } = await this.supabase.client
      .from('posts')
      .insert({
        author_id: user.id,
        content: body.content.trim(),
        image_url: imageUrl,
        visibility,
        university_id: profile?.university_id ?? null,
        tags,
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
  async getFeed(
    @Headers('authorization') authHeader: string,
    @Query('tag') tag?: string,
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '20',
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    const universityId = profile?.university_id;
    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const size = Math.min(50, Math.max(1, parseInt(pageSize, 10) || 20));
    const from = (pageNum - 1) * size;
    const to = from + size - 1;

    let query = this.supabase.client
      .from('posts')
      .select('*, profiles(full_name, username, avatar_url, is_verified)', { count: 'exact' })
      .eq('type', 'post')
      .eq('is_removed', false)
      .order('created_at', { ascending: false })
      .range(from, to);

    if (universityId) {
      query = query.or(`visibility.eq.global,and(visibility.eq.university,university_id.eq.${universityId})`);
    } else {
      query = query.eq('visibility', 'global');
    }
    if (tag) query = query.contains('tags', [tag]);

    const { data, error, count } = await query;

    if (error) {
      console.error('Feed query error:', error);
      return { success: false, error: error.message };
    }

    const { data: blocks } = await this.supabase.client
      .from('blocked_users')
      .select('blocker_id, blocked_id')
      .or(`blocker_id.eq.${user.id},blocked_id.eq.${user.id}`);

    const blockedAuthorIds = new Set(
      (blocks ?? []).map((b) => (b.blocker_id === user.id ? b.blocked_id : b.blocker_id)),
    );
    const filtered = (data ?? []).filter((p) => !blockedAuthorIds.has(p.author_id));

    const postIds = filtered.map((p) => p.id);
    let reactionsByPost: Record<string, { like: number; love: number }> = {};
    let userReactions: Record<string, Set<string>> = {};
    let commentCounts: Record<string, number> = {};

    if (postIds.length > 0) {
      const { data: reactions } = await this.supabase.client
        .from('reactions')
        .select('post_id, user_id, reaction_type')
        .in('post_id', postIds);

      reactions?.forEach((r) => {
        if (!reactionsByPost[r.post_id]) reactionsByPost[r.post_id] = { like: 0, love: 0 };
        reactionsByPost[r.post_id][r.reaction_type as 'like' | 'love']++;
        if (r.user_id === user.id) {
          if (!userReactions[r.post_id]) userReactions[r.post_id] = new Set();
          userReactions[r.post_id].add(r.reaction_type);
        }
      });

      const { data: comments } = await this.supabase.client
        .from('comments')
        .select('post_id')
        .in('post_id', postIds);
      comments?.forEach((c) => {
        commentCounts[c.post_id] = (commentCounts[c.post_id] ?? 0) + 1;
      });
    }

    const enriched = filtered.map((p) => ({
      ...p,
      reactionCounts: reactionsByPost[p.id] ?? { like: 0, love: 0 },
      myReactions: Array.from(userReactions[p.id] ?? []),
      commentCount: commentCounts[p.id] ?? 0,
    }));

    return { success: true, posts: enriched, total: count ?? 0, page: pageNum, pageSize: size };
  }

  @Get('notices')
  async getNotices(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    let query = this.supabase.client
      .from('posts')
      .select('*, profiles(full_name, username, avatar_url)')
      .eq('type', 'notice')
      .eq('is_removed', false)
      .order('created_at', { ascending: false });

    if (profile?.university_id) {
      query = query.or(`visibility.eq.global,and(visibility.eq.university,university_id.eq.${profile.university_id})`);
    } else {
      query = query.eq('visibility', 'global');
    }

    const { data, error } = await query;
    if (error) return { success: false, error: error.message };
    return { success: true, notices: data };
  }

  @Get('trending')
  async getTrending(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    const since = new Date();
    since.setDate(since.getDate() - 7);

    let query = this.supabase.client
      .from('posts')
      .select('tags')
      .eq('type', 'post')
      .eq('is_removed', false)
      .gte('created_at', since.toISOString())
      .not('tags', 'is', null);

    if (profile?.university_id) {
      query = query.eq('university_id', profile.university_id);
    }

    const { data, error } = await query;
    if (error) return { success: false, error: error.message };

    const counts: Record<string, number> = {};
    for (const row of data ?? []) {
      for (const t of row.tags ?? []) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }

    const top = Object.entries(counts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([label, count]) => ({ label, count }));

    return { success: true, trending: top };
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
    if (!deleted || deleted.length === 0) return { success: false, error: 'Post not found or not yours to delete' };
    return { success: true };
  }

  @Post(':id/react')
  async toggleReaction(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { reactionType?: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

    const reactionType = body.reactionType === 'love' ? 'love' : 'like';

    const { data: existing } = await this.supabase.client
      .from('reactions')
      .select('id')
      .eq('post_id', id)
      .eq('user_id', user.id)
      .eq('reaction_type', reactionType)
      .maybeSingle();

    if (existing) {
      await this.supabase.client.from('reactions').delete().eq('id', existing.id);
      return { success: true, reacted: false, reactionType };
    } else {
      await this.supabase.client.from('reactions').insert({ post_id: id, user_id: user.id, reaction_type: reactionType });
      return { success: true, reacted: true, reactionType };
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
    await this.supabase.assertNotRestricted(user.id);

    if (!body.content?.trim()) return { success: false, error: 'Comment cannot be empty' };

    const { data, error } = await this.supabase.client
      .from('comments')
      .insert({ post_id: id, author_id: user.id, content: body.content.trim(), parent_comment_id: body.parentCommentId ?? null })
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
    if (!body.reason?.trim()) return { success: false, error: 'Please provide a reason' };

    const { data: post } = await this.supabase.client.from('posts').select('author_id').eq('id', id).single();

    const { error } = await this.supabase.client
      .from('reports')
      .insert({ target_type: 'post', target_id: id, reported_user_id: post?.author_id ?? null, reported_by: user.id, reason: body.reason.trim() });
    if (error) return { success: false, error: error.message };
    return { success: true };
  }
}