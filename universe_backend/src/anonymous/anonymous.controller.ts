import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Param,
  Patch,
  Post,
  Query,
  UnauthorizedException,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('anonymous')
export class AnonymousController {
  constructor(private readonly supabase: SupabaseService) {}

  private async getUserFromToken(authHeader?: string) {
    if (!authHeader?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing token');
    }

    const token = authHeader.replace('Bearer ', '');

    const { data, error } =
      await this.supabase.client.auth.getUser(token);

    if (error || !data.user) {
      throw new UnauthorizedException('Invalid token');
    }

    return data.user;
  }

  @Get('profile')
  async getMyAnonymousProfile(
    @Headers('authorization') authHeader: string,
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('anonymous_profiles')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle();

    if (error) {
      return {
        success: false,
        error: error.message,
      };
    }

    return {
      success: true,
      profile: data,
    };
  }

  @Post('profile/check-username')
  async checkUsername(
    @Body() body: { username: string },
  ) {
    const username = body.username?.trim().toLowerCase();

    if (
      !username ||
      username.length < 3 ||
      username.length > 20
    ) {
      return {
        available: false,
        error: 'Username must be 3-20 characters',
      };
    }

    if (!/^[a-z0-9_]+$/.test(username)) {
      return {
        available: false,
        error:
          'Only lowercase letters, numbers, and underscores allowed',
      };
    }

    const { data } = await this.supabase.client
      .from('anonymous_profiles')
      .select('id')
      .eq('anonymous_username', username)
      .maybeSingle();

    return {
      available: !data,
    };
  }

  @Post('profile')
  async createAnonymousProfile(
    @Headers('authorization') authHeader: string,
    @Body() body: { username: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    const username = body.username?.trim().toLowerCase();

    if (
      !username ||
      username.length < 3 ||
      username.length > 20 ||
      !/^[a-z0-9_]+$/.test(username)
    ) {
      return {
        success: false,
        error: 'Invalid username',
      };
    }

    const { data: existingProfile } =
      await this.supabase.client
        .from('anonymous_profiles')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (existingProfile) {
      return {
        success: false,
        error: 'You already have an anonymous identity',
      };
    }

    const { data, error } =
      await this.supabase.client
        .from('anonymous_profiles')
        .insert({
          user_id: user.id,
          anonymous_username: username,
        })
        .select()
        .single();

    if (error) {
      if (error.code === '23505') {
        return {
          success: false,
          error: 'That username is already taken',
        };
      }

      return {
        success: false,
        error: error.message,
      };
    }

    return {
      success: true,
      profile: data,
    };
  }

  @Get('feed')
  async getFeed(
    @Headers('authorization') authHeader: string,
    @Query('sort') sort?: string, // 'recent' (default) | 'trending'
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('anonymous_posts')
      .select(
        '*, anonymous_profiles(anonymous_username, avatar_url)',
      )
      .order('created_at', {
        ascending: false,
      });

    if (error) {
      return {
        success: false,
        error: error.message,
      };
    }

    const posts = data ?? [];
    const postIds = posts.map((p: any) => p.id);
    let reactionCounts: Record<string, number> = {};
    let myReactedIds = new Set<string>();

    if (postIds.length > 0) {
      const { data: reactions } = await this.supabase.client
        .from('anonymous_post_reactions')
        .select('post_id, user_id')
        .in('post_id', postIds);

      reactions?.forEach((r) => {
        reactionCounts[r.post_id] = (reactionCounts[r.post_id] ?? 0) + 1;
        if (r.user_id === user.id) myReactedIds.add(r.post_id);
      });

      const { data: saved } = await this.supabase.client
        .from('saved_anonymous_posts')
        .select('post_id')
        .eq('user_id', user.id)
        .in('post_id', postIds);
      var savedSet = new Set((saved ?? []).map((s) => s.post_id));
    } else {
      var savedSet = new Set<string>();
    }

    let enriched = posts.map((p: any) => ({
      ...p,
      reactionCount: reactionCounts[p.id] ?? 0,
      hasReacted: myReactedIds.has(p.id),
      isSaved: savedSet.has(p.id),
    }));

    if (sort === 'trending') {
      // Trending = engagement-weighted over a recent window, matching the
      // same approach as the regular feed's Trending screen -- here that's
      // reaction count within the last 7 days, since anonymous posts don't
      // carry the tag-based trending model posts.tags does.
      const since = Date.now() - 7 * 24 * 60 * 60 * 1000;
      enriched = enriched
        .filter((p: any) => new Date(p.created_at).getTime() >= since)
        .sort((a: any, b: any) => b.reactionCount - a.reactionCount);
    }

    return {
      success: true,
      posts: enriched,
    };
  }

  @Post('posts/:id/react')
  async togglePostReaction(@Headers('authorization') authHeader: string, @Param('id') postId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: existing } = await this.supabase.client
      .from('anonymous_post_reactions')
      .select('id')
      .eq('post_id', postId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existing) {
      await this.supabase.client.from('anonymous_post_reactions').delete().eq('id', existing.id);
      return { success: true, reacted: false };
    } else {
      await this.supabase.client.from('anonymous_post_reactions').insert({ post_id: postId, user_id: user.id });
      return { success: true, reacted: true };
    }
  }

  @Post('posts/:id/save')
  async toggleSavePost(@Headers('authorization') authHeader: string, @Param('id') postId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: existing } = await this.supabase.client
      .from('saved_anonymous_posts')
      .select('id')
      .eq('post_id', postId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existing) {
      await this.supabase.client.from('saved_anonymous_posts').delete().eq('id', existing.id);
      return { success: true, saved: false };
    } else {
      await this.supabase.client.from('saved_anonymous_posts').insert({ post_id: postId, user_id: user.id });
      return { success: true, saved: true };
    }
  }

  @Get('saved')
  async getSavedPosts(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('saved_anonymous_posts')
      .select('created_at, anonymous_posts(*, anonymous_profiles(anonymous_username, avatar_url))')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false });

    if (error) return { success: false, error: error.message };
    return { success: true, posts: (data ?? []).map((s: any) => s.anonymous_posts).filter(Boolean) };
  }

  @Post('posts/:id/reshare')
  async reshare(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: original, error: fetchError } = await this.supabase.client
      .from('anonymous_posts')
      .select('id, reposted_post_id, category')
      .eq('id', id)
      .single();

    if (fetchError || !original) {
      return { success: false, error: 'Original post not found' };
    }
    if (original.reposted_post_id) {
      // Same one-level cap as the regular feed's reshare -- always point at
      // the true original, never chain reshares of reshares.
      return { success: false, error: 'Cannot reshare a repost -- share the original post instead' };
    }

    const { data: anonProfile } = await this.supabase.client
      .from('anonymous_profiles')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!anonProfile) {
      return { success: false, error: 'Create an anonymous identity first' };
    }

    const { data, error } = await this.supabase.client
      .from('anonymous_posts')
      .insert({
        anonymous_profile_id: anonProfile.id,
        content: '',
        category: original.category,
        reposted_post_id: original.id,
      })
      .select()
      .single();

    if (error) return { success: false, error: error.message };
    return { success: true, post: data };
  }

  @Post('polls')
  async createPoll(
    @Headers('authorization') authHeader: string,
    @Body() body: { anonymousPostId: string; question: string; options: string[] },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.question?.trim() || !body.options || body.options.length < 2) {
      return { success: false, error: 'A question and at least 2 options are required' };
    }

    const { data: anonProfile } = await this.supabase.client
      .from('anonymous_profiles')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!anonProfile) {
      return { success: false, error: 'Create an anonymous identity first' };
    }

    const { data: post } = await this.supabase.client
      .from('anonymous_posts')
      .select('id, anonymous_profile_id')
      .eq('id', body.anonymousPostId)
      .single();

    if (!post || post.anonymous_profile_id !== anonProfile.id) {
      return { success: false, error: 'You can only attach a poll to your own post' };
    }

    const { data, error } = await this.supabase.client
      .from('polls')
      .insert({
        anonymous_post_id: body.anonymousPostId,
        question: body.question.trim(),
        options: body.options.map((o) => o.trim()).filter(Boolean),
      })
      .select()
      .single();

    if (error) return { success: false, error: error.message };
    return { success: true, poll: data };
  }

  @Post('polls/:id/vote')
  async votePoll(
    @Headers('authorization') authHeader: string,
    @Param('id') pollId: string,
    @Body() body: { optionIndex: number },
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data: poll } = await this.supabase.client
      .from('polls')
      .select('options')
      .eq('id', pollId)
      .single();

    if (!poll || body.optionIndex < 0 || body.optionIndex >= poll.options.length) {
      return { success: false, error: 'Invalid poll or option' };
    }

    const { error } = await this.supabase.client
      .from('poll_votes')
      .upsert(
        { poll_id: pollId, user_id: user.id, option_index: body.optionIndex },
        { onConflict: 'poll_id,user_id' },
      );

    if (error) return { success: false, error: error.message };

    const { data: allVotes } = await this.supabase.client
      .from('poll_votes')
      .select('option_index')
      .eq('poll_id', pollId);

    const counts = new Array(poll.options.length).fill(0);
    (allVotes ?? []).forEach((v) => counts[v.option_index]++);

    return { success: true, counts, myVote: body.optionIndex };
  }

  // 5 anonymous posts per minute
  @Post('posts')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  async createPost(
    @Headers('authorization') authHeader: string,
    @Body()
    body: {
      content: string;
      category: string;
    },
  ) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

    const { data: anonProfile } =
      await this.supabase.client
        .from('anonymous_profiles')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (!anonProfile) {
      return {
        success: false,
        error: 'Create an anonymous identity first',
      };
    }

    if (!body.content?.trim()) {
      return {
        success: false,
        error: 'Post cannot be empty',
      };
    }

    const category = [
      'rant',
      'advice',
      'confession',
      'talk',
    ].includes(body.category)
      ? body.category
      : 'talk';

    const { data, error } =
      await this.supabase.client
        .from('anonymous_posts')
        .insert({
          anonymous_profile_id: anonProfile.id,
          content: body.content.trim(),
          category,
        })
        .select(
          '*, anonymous_profiles(anonymous_username)',
        )
        .single();

    if (error) {
      return {
        success: false,
        error: error.message,
      };
    }

    return {
      success: true,
      post: data,
    };
  }

  @Get('posts/:id/comments')
  async getComments(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } =
      await this.supabase.client
        .from('anonymous_comments')
        .select(
          '*, anonymous_profiles(anonymous_username)',
        )
        .eq('anonymous_post_id', id)
        .order('created_at', {
          ascending: true,
        });

    if (error) {
      return {
        success: false,
        error: error.message,
      };
    }

    const all = data ?? [];
    const commentIds = all.map((c: any) => c.id);
    let reactionCounts: Record<string, number> = {};
    let myReactedIds = new Set<string>();

    if (commentIds.length > 0) {
      const { data: reactions } = await this.supabase.client
        .from('anonymous_comment_reactions')
        .select('comment_id, user_id')
        .in('comment_id', commentIds);

      reactions?.forEach((r) => {
        reactionCounts[r.comment_id] = (reactionCounts[r.comment_id] ?? 0) + 1;
        if (r.user_id === user.id) myReactedIds.add(r.comment_id);
      });
    }

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

    return {
      success: true,
      comments: topLevel,
    };
  }

  @Post('comments/:id/react')
  async toggleCommentReaction(@Headers('authorization') authHeader: string, @Param('id') commentId: string) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

    const { data: existing } = await this.supabase.client
      .from('anonymous_comment_reactions')
      .select('id')
      .eq('comment_id', commentId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existing) {
      await this.supabase.client.from('anonymous_comment_reactions').delete().eq('id', existing.id);
      return { success: true, reacted: false };
    } else {
      await this.supabase.client.from('anonymous_comment_reactions').insert({ comment_id: commentId, user_id: user.id });
      return { success: true, reacted: true };
    }
  }

  // 10 anonymous comments per minute
  @Post('posts/:id/comments')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async addComment(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { content: string; parentCommentId?: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

    const { data: anonProfile } =
      await this.supabase.client
        .from('anonymous_profiles')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (!anonProfile) {
      return {
        success: false,
        error: 'Create an anonymous identity first',
      };
    }

    if (!body.content?.trim()) {
      return {
        success: false,
        error: 'Comment cannot be empty',
      };
    }

    const { data, error } =
      await this.supabase.client
        .from('anonymous_comments')
        .insert({
          anonymous_post_id: id,
          anonymous_profile_id: anonProfile.id,
          content: body.content.trim(),
          parent_comment_id: body.parentCommentId ?? null,
        })
        .select(
          '*, anonymous_profiles(anonymous_username)',
        )
        .single();

    if (error) {
      return {
        success: false,
        error: error.message,
      };
    }

    return {
      success: true,
      comment: data,
    };
  }

  // 10 reports per minute
  @Post('posts/:id/report')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  async reportPost(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { reason: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.reason?.trim()) {
      return {
        success: false,
        error: 'Please provide a reason',
      };
    }

    // Intentionally NOT resolving anonymous_profile_id -> user_id here anymore.
    // The real identity behind an anonymous post is never written to the reports
    // table at all now — it's only ever computed on demand, transiently, by
    // super_admin via POST /admin/reports/:id/reveal-identity, with a required
    // reason and an audit log entry. Do not reintroduce that lookup here.
    const { error } = await this.supabase.client
      .from('reports')
      .insert({
        target_type: 'anonymous_post',
        target_id: id,
        reported_user_id: null,
        reported_by: user.id,
        reason: body.reason.trim(),
      });

    if (error) {
      return {
        success: false,
        error: error.message,
      };
    }

    return {
      success: true,
    };
  }

  @Patch('profile')
  async updateAnonymousUsername(
    @Headers('authorization') authHeader: string,
    @Body() body: { username: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    const username = body.username?.trim().toLowerCase();

    if (
      !username ||
      username.length < 3 ||
      username.length > 20 ||
      !/^[a-z0-9_]+$/.test(username)
    ) {
      return {
        success: false,
        error: 'Invalid username',
      };
    }

    const { data: updated, error } =
      await this.supabase.client
        .from('anonymous_profiles')
        .update({
          anonymous_username: username,
        })
        .eq('user_id', user.id)
        .select();

    if (error) {
      if (error.code === '23505') {
        return {
          success: false,
          error: 'That username is already taken',
        };
      }

      return {
        success: false,
        error: error.message,
      };
    }

    if (!updated || updated.length === 0) {
      return {
        success: false,
        error: 'No anonymous identity found',
      };
    }

    return {
      success: true,
    };
  }
}