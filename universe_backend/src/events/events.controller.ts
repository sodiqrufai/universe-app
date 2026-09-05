import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Query, UnauthorizedException, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('events')
export class EventsController {
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

  @Get('categories')
  async getCategories() {
    const { data, error } = await this.supabase.client
      .from('event_categories')
      .select('*')
      .order('name');
    if (error) return { success: false, error: error.message };
    return { success: true, categories: data };
  }

  @Get()
  async getEvents(
    @Headers('authorization') authHeader: string,
    @Query('categoryId') categoryId?: string,
    @Query('search') search?: string,
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    if (!profile?.university_id) {
      return { success: true, events: [] };
    }

    let query = this.supabase.client
      .from('events')
      .select('*, profiles(full_name, username, avatar_url), event_rsvps(user_id, status)')
      .eq('status', 'active')
      .order('starts_at', { ascending: true })
      .eq('university_id', profile.university_id);

    if (categoryId) query = query.eq('category_id', categoryId);
    if (search) query = query.textSearch('search_vector', search, { type: 'websearch', config: 'english' });

    const { data, error } = await query;
    if (error) return { success: false, error: error.message };

    const { data: blocks } = await this.supabase.client
      .from('blocked_users')
      .select('blocker_id, blocked_id')
      .or(`blocker_id.eq.${user.id},blocked_id.eq.${user.id}`);

    const blockedOrganizerIds = new Set(
      (blocks ?? []).map((b) => (b.blocker_id === user.id ? b.blocked_id : b.blocker_id)),
    );
    const visibleEvents = (data ?? []).filter((e: any) => !blockedOrganizerIds.has(e.organizer_id));

    const enriched = visibleEvents.map((e: any) => {
      const goingCount = e.event_rsvps?.filter((r: any) => r.status === 'going').length ?? 0;
      const myRsvp = e.event_rsvps?.find((r: any) => r.user_id === user.id)?.status ?? null;
      return { ...e, goingCount, myRsvp };
    });

    return { success: true, events: enriched };
  }

  @Get('mine')
  async getMyEvents(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('event_rsvps')
      .select('status, events(*, profiles(full_name))')
      .eq('user_id', user.id);

    if (error) return { success: false, error: error.message };
    return { success: true, events: data };
  }

  @Get(':id')
  async getEvent(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('events')
      .select('*, profiles(full_name, username, avatar_url), event_rsvps(user_id, status)')
      .eq('id', id)
      .single();

    if (error) return { success: false, error: error.message };

    const goingCount = (data as any).event_rsvps?.filter((r: any) => r.status === 'going').length ?? 0;
    const interestedCount = (data as any).event_rsvps?.filter((r: any) => r.status === 'interested').length ?? 0;
    const myRsvp = (data as any).event_rsvps?.find((r: any) => r.user_id === user.id)?.status ?? null;

    return { success: true, event: { ...data, goingCount, interestedCount, myRsvp } };
  }

  @Post()
  @UseInterceptors(FileInterceptor('cover'))
  async createEvent(
    @Headers('authorization') authHeader: string,
    @UploadedFile() file: any,
    @Body() body: { title: string; description: string; location: string; startsAt: string; categoryId: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

    if (!body.title?.trim() || !body.startsAt) {
      return { success: false, error: 'Title and date/time are required' };
    }

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    let coverUrl: string | null = null;
    if (file) {
      const filePath = `${user.id}/${Date.now()}.jpg`;
      const { error: uploadError } = await this.supabase.client.storage
        .from('event-covers')
        .upload(filePath, file.buffer, { contentType: file.mimetype });
      if (!uploadError) {
        const { data: urlData } = this.supabase.client.storage.from('event-covers').getPublicUrl(filePath);
        coverUrl = urlData.publicUrl;
      }
    }

    const { data, error } = await this.supabase.client
      .from('events')
      .insert({
        organizer_id: user.id,
        category_id: body.categoryId || null,
        university_id: profile?.university_id ?? null,
        title: body.title.trim(),
        description: body.description?.trim() ?? null,
        location: body.location?.trim() ?? null,
        starts_at: body.startsAt,
        cover_image_url: coverUrl,
      })
      .select()
      .single();

    if (error) return { success: false, error: error.message };
    return { success: true, event: data };
  }

  @Post(':id/rsvp')
  async rsvp(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { status: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

    if (!['interested', 'going'].includes(body.status)) {
      return { success: false, error: 'Invalid RSVP status' };
    }

    const { error } = await this.supabase.client
      .from('event_rsvps')
      .upsert({ event_id: id, user_id: user.id, status: body.status }, { onConflict: 'event_id,user_id' });

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Delete(':id/rsvp')
  async cancelRsvp(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('event_rsvps')
      .delete()
      .eq('event_id', id)
      .eq('user_id', user.id);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Patch(':id/cancel')
  async cancelEvent(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: updated, error } = await this.supabase.client
      .from('events')
      .update({ status: 'cancelled' })
      .eq('id', id)
      .eq('organizer_id', user.id)
      .select();

    if (error) return { success: false, error: error.message };
    if (!updated || updated.length === 0) {
      return { success: false, error: 'Event not found or you are not the organizer' };
    }
    return { success: true };
  }

    @Post(':id/report')
  async reportEvent(@Headers('authorization') authHeader: string, @Param('id') id: string, @Body() body: { reason: string }) {
    const user = await this.getUserFromToken(authHeader);
    if (!body.reason?.trim()) return { success: false, error: 'Reason required' };

    const { data: event } = await this.supabase.client.from('events').select('organizer_id').eq('id', id).single();
    const { error } = await this.supabase.client
      .from('reports')
      .insert({ target_type: 'event', target_id: id, reported_user_id: event?.organizer_id ?? null, reported_by: user.id, reason: body.reason.trim() });
    if (error) return { success: false, error: error.message };
    return { success: true };
  }
}