import { Controller, Get, Headers, Query, UnauthorizedException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('search')
export class SearchController {
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

  @Get()
  async search(
    @Headers('authorization') authHeader: string,
    @Query('q') q?: string,
    @Query('page') page = '1',
    @Query('pageSize') pageSize = '10',
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!q?.trim() || q.trim().length < 2) {
      return { success: false, error: 'Search query must be at least 2 characters' };
    }
    const query = q.trim();

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    // University scoping is ALWAYS derived from the requesting user's own
    // profile, never from a client-supplied param -- accepting a client-given
    // universityId here would let any student search another university's
    // content, which is exactly the leak this endpoint must not allow.
    const universityId = profile?.university_id ?? null;

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const size = Math.min(20, Math.max(1, parseInt(pageSize, 10) || 10));
    const from = (pageNum - 1) * size;
    const to = from + size - 1;

    const { data: blocks } = await this.supabase.client
      .from('blocked_users')
      .select('blocker_id, blocked_id')
      .or(`blocker_id.eq.${user.id},blocked_id.eq.${user.id}`);
    const blockedIds = new Set(
      (blocks ?? []).map((b) => (b.blocker_id === user.id ? b.blocked_id : b.blocker_id)),
    );

    const [posts, listings, services, events, resources] = await Promise.all([
      this.searchPosts(query, universityId),
      this.searchListings(query, universityId),
      this.searchServices(query, universityId),
      this.searchEvents(query, universityId),
      this.searchResources(query, universityId),
    ]);

    const filteredPosts = posts.filter((p: any) => !blockedIds.has(p.author_id));
    const filteredListings = listings.filter((l: any) => !blockedIds.has(l.seller_id));
    const filteredServices = services.filter((s: any) => !blockedIds.has(s.provider_id));
    const filteredEvents = events.filter((e: any) => !blockedIds.has(e.organizer_id));
    const filteredResources = resources.filter((r: any) => !blockedIds.has(r.uploader_id));

    const paginate = (arr: any[]) => arr.slice(from, to + 1);

    return {
      success: true,
      results: {
        posts: { items: paginate(filteredPosts), total: filteredPosts.length },
        listings: { items: paginate(filteredListings), total: filteredListings.length },
        services: { items: paginate(filteredServices), total: filteredServices.length },
        events: { items: paginate(filteredEvents), total: filteredEvents.length },
        resources: { items: paginate(filteredResources), total: filteredResources.length },
      },
      page: pageNum,
      pageSize: size,
    };
  }

  private async searchPosts(query: string, universityId: string | null) {
    let q = this.supabase.client
      .from('posts')
      .select('*, profiles(full_name, username, avatar_url, is_verified)')
      .eq('type', 'post')
      .eq('is_removed', false)
      .textSearch('search_vector', query, { type: 'websearch', config: 'english' })
      .order('created_at', { ascending: false });

    if (universityId) {
      q = q.or(`visibility.eq.global,and(visibility.eq.university,university_id.eq.${universityId})`);
    } else {
      q = q.eq('visibility', 'global');
    }

    const { data, error } = await q;
    if (error) {
      console.error('Search posts error:', error);
      return [];
    }
    return (data ?? []).map((p: any) => ({ ...p, resultType: 'post' }));
  }

  private async searchListings(query: string, universityId: string | null) {
    let q = this.supabase.client
      .from('listings')
      .select('*, profiles(full_name, username, avatar_url), listing_images(image_url, sort_order)')
      .eq('status', 'active')
      .textSearch('search_vector', query, { type: 'websearch', config: 'english' })
      .order('created_at', { ascending: false });

    if (universityId) q = q.eq('university_id', universityId);

    const { data, error } = await q;
    if (error) {
      console.error('Search listings error:', error);
      return [];
    }
    return (data ?? []).map((l: any) => ({ ...l, resultType: 'listing' }));
  }

  private async searchServices(query: string, universityId: string | null) {
    let q = this.supabase.client
      .from('services')
      .select('*, profiles(full_name, username, avatar_url), service_images(image_url, sort_order)')
      .eq('status', 'active')
      .textSearch('search_vector', query, { type: 'websearch', config: 'english' })
      .order('created_at', { ascending: false });

    if (universityId) q = q.eq('university_id', universityId);

    const { data, error } = await q;
    if (error) {
      console.error('Search services error:', error);
      return [];
    }
    return (data ?? []).map((s: any) => ({ ...s, resultType: 'service' }));
  }

  private async searchEvents(query: string, universityId: string | null) {
    let q = this.supabase.client
      .from('events')
      .select('*, profiles(full_name, username, avatar_url)')
      .eq('status', 'active')
      .textSearch('search_vector', query, { type: 'websearch', config: 'english' })
      .order('starts_at', { ascending: true });

    if (universityId) q = q.eq('university_id', universityId);

    const { data, error } = await q;
    if (error) {
      console.error('Search events error:', error);
      return [];
    }
    return (data ?? []).map((e: any) => ({ ...e, resultType: 'event' }));
  }

  private async searchResources(query: string, universityId: string | null) {
    // Scoped via courses -> departments -> faculties -> university_id since
    // resources has no direct university_id column of its own.
    let q = this.supabase.client
      .from('resources')
      .select('*, profiles(full_name, username), courses!inner(name, departments!inner(name, faculties!inner(name, university_id)))')
      .textSearch('search_vector', query, { type: 'websearch', config: 'english' })
      .order('created_at', { ascending: false });

    if (universityId) {
      q = q.eq('courses.departments.faculties.university_id', universityId);
    }

    const { data, error } = await q;
    if (error) {
      console.error('Search resources error:', error);
      return [];
    }
    return (data ?? []).map((r: any) => ({ ...r, resultType: 'resource' }));
  }
}
