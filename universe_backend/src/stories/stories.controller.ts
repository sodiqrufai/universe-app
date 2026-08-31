import { Body, Controller, Delete, Get, Headers, Param, Post, UnauthorizedException, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('stories')
export class StoriesController {
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
  async createStory(
    @Headers('authorization') authHeader: string,
    @UploadedFile() file: any,
    @Body() body: { mediaType: string; caption?: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!file) {
      return { success: false, error: 'No media file provided' };
    }
    const mediaType = ['image', 'video'].includes(body.mediaType) ? body.mediaType : 'image';

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    const ext = mediaType === 'video' ? 'mp4' : 'jpg';
    const filePath = `${user.id}/${Date.now()}.${ext}`;

    const { error: uploadError } = await this.supabase.client.storage
      .from('story-media')
      .upload(filePath, file.buffer, { contentType: file.mimetype });

    if (uploadError) {
      console.error('Story media upload error:', uploadError);
      return { success: false, error: uploadError.message };
    }

    const { data: urlData } = this.supabase.client.storage.from('story-media').getPublicUrl(filePath);

    const { data, error } = await this.supabase.client
      .from('stories')
      .insert({
        author_id: user.id,
        university_id: profile?.university_id ?? null,
        media_url: urlData.publicUrl,
        media_type: mediaType,
        caption: body.caption?.trim() || null,
      })
      .select()
      .single();

    if (error) {
      console.error('Create story error:', error);
      return { success: false, error: error.message };
    }
    console.log('[stories] created story:', { id: data.id, author_id: data.author_id, university_id: data.university_id, expires_at: data.expires_at });
    return { success: true, story: data };
  }

  @Get()
  async getStories(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    console.log('[stories] requesting user:', user.id, 'university_id:', profile?.university_id);

    let query = this.supabase.client
      .from('stories')
      .select('*, profiles(full_name, username, avatar_url)')
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: true });

    if (profile?.university_id) {
      query = query.or(`university_id.is.null,university_id.eq.${profile.university_id}`);
    } else {
      query = query.is('university_id', null);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Get stories error:', error);
      return { success: false, error: error.message };
    }

    console.log(
      '[stories] raw rows returned:',
      (data ?? []).length,
      (data ?? []).map((s: any) => ({
        id: s.id,
        author_id: s.author_id,
        university_id: s.university_id,
        expires_at: s.expires_at,
      })),
    );

    const storyIds = (data ?? []).map((s) => s.id);
    let viewedSet = new Set<string>();
    if (storyIds.length > 0) {
      const { data: views } = await this.supabase.client
        .from('story_views')
        .select('story_id')
        .eq('viewer_id', user.id)
        .in('story_id', storyIds);
      views?.forEach((v) => viewedSet.add(v.story_id));
    }

    // Group by author for the carousel: each author gets one entry with their list of stories.
    const grouped = new Map<string, any>();
    for (const s of data ?? []) {
      const authorId = s.author_id;
      if (!grouped.has(authorId)) {
        grouped.set(authorId, {
          authorId,
          profile: s.profiles,
          hasUnviewed: false,
          stories: [],
        });
      }
      const entry = grouped.get(authorId);
      const viewed = viewedSet.has(s.id);
      if (!viewed) entry.hasUnviewed = true;
      entry.stories.push({ ...s, viewed });
    }

    console.log('[stories] grouped author entries:', Array.from(grouped.values()).length);
    return { success: true, authors: Array.from(grouped.values()) };
  }

  @Post(':id/view')
  async recordView(@Headers('authorization') authHeader: string, @Param('id') storyId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('story_views')
      .upsert(
        { story_id: storyId, viewer_id: user.id, viewed_at: new Date().toISOString() },
        { onConflict: 'story_id,viewer_id' },
      );

    if (error) {
      console.error('Record story view error:', error);
      return { success: false, error: error.message };
    }
    return { success: true };
  }

  @Delete(':id')
  async deleteStory(@Headers('authorization') authHeader: string, @Param('id') storyId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: deleted, error } = await this.supabase.client
      .from('stories')
      .delete()
      .eq('id', storyId)
      .eq('author_id', user.id)
      .select();

    if (error) return { success: false, error: error.message };
    if (!deleted || deleted.length === 0) {
      return { success: false, error: 'Story not found or not yours' };
    }
    return { success: true };
  }
}