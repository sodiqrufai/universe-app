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

  @Post(':id/reshare')
  async resharePost(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

    const { data: original, error: fetchError } = await this.supabase.client
      .from('posts')
      .select('id, reposted_post_id, is_removed, university_id')
      .eq('id', id)
      .single();

    if (fetchError || !original) {
      return { success: false, error: 'Original post not found' };
    }
    if (original.is_removed) {
      return { success: false, error: 'This post is no longer available' };
    }
    if (original.reposted_post_id) {
      // One-level cap: you can reshare an original post, but not a reshare of
      // a reshare. Always point at the true original, never chain them.
      return { success: false, error: 'Cannot reshare a repost -- share the original post instead' };
    }

    const { data, error } = await this.supabase.client
      .from('posts')
      .insert({
        author_id: user.id,
        content: '',
        visibility: 'university',
        university_id: original.university_id,
        reposted_post_id: original.id,
      })
      .select()
      .single();

    if (error) {
      console.error('Reshare error:', error);
      return { success: false, error: error.message };
    }
    return { success: true, post: data };
  }

  @Get('feed')
  async getFeed(
    @Headers('authorization') authHeader: string,
    @Query('tag') tag?: string,
    @Query('filter') filter?: string, // 'all' (default) | 'following' | 'university'
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

    // 'following' needs the set of authors up front to filter by author_id,
    // which range-based pagination interacts with -- resolve it before the
    // main query rather than filtering the page's results after the fact,
    // or pagination counts would be wrong for this filter specifically.
    let followingIds: string[] | null = null;
    if (filter === 'following') {
      const { data: follows } = await this.supabase.client
        .from('follows')
        .select('followed_id')
        .eq('follower_id', user.id);
      followingIds = (follows ?? []).map((f) => f.followed_id);
      if (followingIds.length === 0) {
        return { success: true, posts: [], total: 0, page: pageNum, pageSize: size };
      }
    }

    let query = this.supabase.client
      .from('posts')
      .select('*, profiles(full_name, username, avatar_url, is_verified)', { count: 'exact' })
      .eq('type', 'post')
      .eq('is_removed', false)
      .order('created_at', { ascending: false })
      .range(from, to);

    if (filter === 'following' && followingIds) {
      query = query.in('author_id', followingIds);
    } else if (filter === 'university') {
      if (universityId) {
        query = query.eq('visibility', 'university').eq('university_id', universityId);
      } else {
        // No university on this profile -- nothing can match a
        // university-scoped filter, so return empty rather than silently
        // falling back to "all".
        return { success: true, posts: [], total: 0, page: pageNum, pageSize: size };
      }
    } else if (universityId) {
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

    // Resolve reposted original content in one batch query rather than N+1.
    const repostSourceIds = filtered
      .map((p: any) => p.reposted_post_id)
      .filter((id: string | null) => !!id);

    let originalsById: Record<string, any> = {};
    if (repostSourceIds.length > 0) {
      const { data: originals } = await this.supabase.client
        .from('posts')
        .select('id, content, image_url, is_removed, profiles(full_name, username, avatar_url, is_verified)')
        .in('id', repostSourceIds);
      (originals ?? []).forEach((o: any) => {
        originalsById[o.id] = o;
      });
    }

    const postIds = filtered.map((p) => p.id);
    let reactionsByPost: Record<string, { like: number; love: number }> = {};
    let userReactions: Record<string, Set<string>> = {};
    let commentCounts: Record<string, number> = {};
    let savedSet = new Set<string>();

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

      const { data: saved } = await this.supabase.client
        .from('saved_posts')
        .select('post_id')
        .eq('user_id', user.id)
        .in('post_id', postIds);
      savedSet = new Set((saved ?? []).map((s) => s.post_id));
    }

    const enriched = filtered.map((p: any) => {
      let repost: any = undefined;
      if (p.reposted_post_id) {
        const original = originalsById[p.reposted_post_id];
        repost = original && !original.is_removed
          ? original
          : { deleted: true };
      }
      return {
        ...p,
        repost,
        reactionCounts: reactionsByPost[p.id] ?? { like: 0, love: 0 },
        myReactions: Array.from(userReactions[p.id] ?? []),
        commentCount: commentCounts[p.id] ?? 0,
        isSaved: savedSet.has(p.id),
      };
    });

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

  @Get('saved')
  async getSavedPosts(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('saved_posts')
      .select('created_at, posts(*, profiles(full_name, username, avatar_url, is_verified))')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false });

    if (error) return { success: false, error: error.message };
    return { success: true, posts: (data ?? []).map((s: any) => s.posts).filter(Boolean) };
  }

  @Post(':id/save')
  async toggleSavePost(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: existing } = await this.supabase.client
      .from('saved_posts')
      .select('id')
      .eq('post_id', id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existing) {
      await this.supabase.client.from('saved_posts').delete().eq('id', existing.id);
      return { success: true, saved: false };
    } else {
      await this.supabase.client.from('saved_posts').insert({ post_id: id, user_id: user.id });
      return { success: true, saved: true };
    }
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
    const user = await this.getUserFromToken(authHeader);
    const { data, error } = await this.supabase.client
      .from('comments')
      .select('*, profiles(full_name, username, avatar_url)')
      .eq('post_id', id)
      .order('created_at', { ascending: true });
    if (error) return { success: false, error: error.message };

    const all = data ?? [];
    const commentIds = all.map((c: any) => c.id);
    let reactionCounts: Record<string, number> = {};
    let myReactedIds = new Set<string>();

    if (commentIds.length > 0) {
      const { data: reactions } = await this.supabase.client
        .from('comment_reactions')
        .select('comment_id, user_id')
        .in('comment_id', commentIds);

      reactions?.forEach((r) => {
        reactionCounts[r.comment_id] = (reactionCounts[r.comment_id] ?? 0) + 1;
        if (r.user_id === user.id) myReactedIds.add(r.comment_id);
      });
    }

    // Build a two-level tree: top-level comments with their direct replies
    // nested under `replies`. Deeper nesting isn't modeled -- a reply-to-a-reply
    // is flattened onto the original top-level comment's replies list, which
    // matches how most comment UIs (including the one already in the mockup)
    // render threads in practice.
    const byId = new Map(
      all.map((c: any) => [
        c.id,
        { ...c, replies: [] as any[], reactionCount: reactionCounts[c.id] ?? 0, hasReacted: myReactedIds.has(c.id) },
      ]),
    );
    const topLevel: any[] = [];

    for (const c of all as any[]) {
      const node = byId.get(c.id);
      if (c.parent_comment_id && byId.has(c.parent_comment_id)) {
        byId.get(c.parent_comment_id).replies.push(node);
      } else {
        topLevel.push(node);
      }
    }

    return { success: true, comments: topLevel };
  }

  @Post('comments/:id/react')
  async toggleCommentReaction(@Headers('authorization') authHeader: string, @Param('id') commentId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: existing } = await this.supabase.client
      .from('comment_reactions')
      .select('id')
      .eq('comment_id', commentId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existing) {
      await this.supabase.client.from('comment_reactions').delete().eq('id', existing.id);
      return { success: true, reacted: false };
    } else {
      await this.supabase.client.from('comment_reactions').insert({ comment_id: commentId, user_id: user.id });
      return { success: true, reacted: true };
    }
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
