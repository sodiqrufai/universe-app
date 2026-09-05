import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Query, UnauthorizedException, UploadedFiles, UseInterceptors } from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { SupabaseService } from '../supabase/supabase.service';
import { NotificationsService } from '../notifications/notifications.service';

@Controller('marketplace')
export class MarketplaceController {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly notifications: NotificationsService,
  ) {}

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
      .from('marketplace_categories')
      .select('*')
      .order('name');
    if (error) return { success: false, error: error.message };
    return { success: true, categories: data };
  }

  @Get('listings')
  async getListings(
    @Headers('authorization') authHeader: string,
    @Query('categoryId') categoryId?: string,
    @Query('search') search?: string,
    @Query('minPrice') minPrice?: string,
    @Query('maxPrice') maxPrice?: string,
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    if (!profile?.university_id) {
      // Fail safe: listings have no "global" visibility concept (unlike
      // posts), so a profile with no university must never fall through to
      // an unscoped, platform-wide query -- that would leak every
      // university's listings to an account that shouldn't see any of them
      // yet. Return empty instead.
      return { success: true, listings: [] };
    }

    let query = this.supabase.client
      .from('listings')
      .select('*, profiles(full_name, username, avatar_url), listing_images(image_url, sort_order)')
      .eq('status', 'active')
      .order('created_at', { ascending: false })
      .eq('university_id', profile.university_id);
    if (categoryId) query = query.eq('category_id', categoryId);
    if (search) query = query.textSearch('search_vector', search, { type: 'websearch', config: 'english' });
    if (minPrice) query = query.gte('price', minPrice);
    if (maxPrice) query = query.lte('price', maxPrice);

    const { data, error } = await query;
    if (error) return { success: false, error: error.message };

    const { data: blocks } = await this.supabase.client
      .from('blocked_users')
      .select('blocker_id, blocked_id')
      .or(`blocker_id.eq.${user.id},blocked_id.eq.${user.id}`);

    const blockedSellerIds = new Set(
      (blocks ?? []).map((b) => (b.blocker_id === user.id ? b.blocked_id : b.blocker_id)),
    );
    const listings = (data ?? []).filter((l: any) => !blockedSellerIds.has(l.seller_id));

    const listingIds = listings.map((l) => l.id);
    let savedSet = new Set<string>();
    if (listingIds.length > 0) {
      const { data: saved } = await this.supabase.client
        .from('saved_listings')
        .select('listing_id')
        .eq('user_id', user.id)
        .in('listing_id', listingIds);
      saved?.forEach((s) => savedSet.add(s.listing_id));
    }

    const enriched = listings.map((l: any) => ({
      ...l,
      isSaved: savedSet.has(l.id),
    }));

    return { success: true, listings: enriched };
  }

  @Get('listings/:id')
  async getListing(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('listings')
      .select('*, profiles(full_name, username, avatar_url), listing_images(image_url, sort_order)')
      .eq('id', id)
      .single();

    if (error) return { success: false, error: error.message };

    const { data: saved } = await this.supabase.client
      .from('saved_listings')
      .select('id')
      .eq('listing_id', id)
      .eq('user_id', user.id)
      .maybeSingle();

    return { success: true, listing: { ...data, isSaved: !!saved } };
  }

  @Post('listings')
  @UseInterceptors(FilesInterceptor('images', 6))
  async createListing(
    @Headers('authorization') authHeader: string,
    @UploadedFiles() files: any[],
    @Body() body: { title: string; description: string; price: string; condition: string; categoryId: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

    if (!body.title?.trim() || !body.price) {
      return { success: false, error: 'Title and price are required' };
    }

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    const { data: listing, error } = await this.supabase.client
      .from('listings')
      .insert({
        seller_id: user.id,
        category_id: body.categoryId || null,
        university_id: profile?.university_id ?? null,
        title: body.title.trim(),
        description: body.description?.trim() ?? null,
        price: parseFloat(body.price),
        condition: body.condition || null,
      })
      .select()
      .single();

    if (error) return { success: false, error: error.message };

    console.log('Listing images received:', files?.length ?? 0);
    if (files && files.length > 0) {
      for (let i = 0; i < files.length; i++) {
        const filePath = `${user.id}/${listing.id}/${Date.now()}-${i}.jpg`;
        const { error: uploadError } = await this.supabase.client.storage
          .from('listing-images')
          .upload(filePath, files[i].buffer, { contentType: files[i].mimetype });

        if (uploadError) {
          console.error('Listing image upload error:', uploadError);
          continue;
        }

        const { data: urlData } = this.supabase.client.storage.from('listing-images').getPublicUrl(filePath);
        const { error: insertError } = await this.supabase.client
          .from('listing_images')
          .insert({ listing_id: listing.id, image_url: urlData.publicUrl, sort_order: i });

        if (insertError) {
          console.error('Listing image DB insert error:', insertError);
        }
      }
    }

    return { success: true, listing };
  }

  @Post('listings/:id/save')
  async saveListing(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: existing } = await this.supabase.client
      .from('saved_listings')
      .select('id')
      .eq('listing_id', id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (existing) {
      await this.supabase.client.from('saved_listings').delete().eq('id', existing.id);
      return { success: true, saved: false };
    } else {
      await this.supabase.client.from('saved_listings').insert({ listing_id: id, user_id: user.id });
      return { success: true, saved: true };
    }
  }

  @Get('saved')
  async getSaved(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('saved_listings')
      .select('listings(*, profiles(full_name, username, avatar_url), listing_images(image_url, sort_order))')
      .eq('user_id', user.id);

    if (error) return { success: false, error: error.message };
    return { success: true, listings: (data ?? []).map((s: any) => s.listings) };
  }

  @Post('listings/:id/offers')
  async makeOffer(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { amount: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.amount) return { success: false, error: 'Amount is required' };

    const { data, error } = await this.supabase.client
      .from('offers')
      .insert({ listing_id: id, buyer_id: user.id, amount: parseFloat(body.amount) })
      .select()
      .single();

    if (error) return { success: false, error: error.message };

    const { data: listing } = await this.supabase.client
      .from('listings')
      .select('seller_id, title')
      .eq('id', id)
      .single();

    if (listing) {
      await this.notifications.create(
        listing.seller_id,
        'new_offer',
        'New offer received',
        `Someone offered ₦${body.amount} on "${listing.title}"`,
        { listingId: id },
      );
    }

    return { success: true, offer: data };
  }

  @Get('listings/:id/offers')
  async getOffers(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('offers')
      .select('*, profiles(full_name, username)')
      .eq('listing_id', id)
      .order('created_at', { ascending: false });

    if (error) return { success: false, error: error.message };
    return { success: true, offers: data };
  }

  @Patch('offers/:id')
  async respondToOffer(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { status: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!['accepted', 'rejected'].includes(body.status)) {
      return { success: false, error: 'Invalid status' };
    }

    const { data: offer } = await this.supabase.client
      .from('offers')
      .select('listing_id')
      .eq('id', id)
      .single();

    if (!offer) {
      return { success: false, error: 'Offer not found' };
    }

    const { data: listing } = await this.supabase.client
      .from('listings')
      .select('seller_id')
      .eq('id', offer.listing_id)
      .single();

    if (!listing || listing.seller_id !== user.id) {
      return { success: false, error: 'You are not the seller of this listing' };
    }

    const { data: updated, error } = await this.supabase.client
      .from('offers')
      .update({ status: body.status })
      .eq('id', id)
      .select();

    if (error) return { success: false, error: error.message };
    if (!updated || updated.length === 0) {
      return { success: false, error: 'No offer was updated — check the ID' };
    }
    return { success: true };
  }

  @Post('listings/:id/report')
  async reportListing(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { reason: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    if (!body.reason?.trim()) {
      return { success: false, error: 'Reason required' };
    }

    const { data: listing } = await this.supabase.client
      .from('listings')
      .select('seller_id')
      .eq('id', id)
      .single();

    const { error } = await this.supabase.client
      .from('reports')
      .insert({
        target_type: 'listing',
        target_id: id,
        reported_user_id: listing?.seller_id ?? null,
        reported_by: user.id,
        reason: body.reason.trim(),
      });

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Delete('listings/:id')
  async deleteListing(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: deleted, error } = await this.supabase.client
      .from('listings')
      .delete()
      .eq('id', id)
      .eq('seller_id', user.id)
      .select();

    if (error) return { success: false, error: error.message };
    if (!deleted || deleted.length === 0) {
      return { success: false, error: 'Listing not found or not yours' };
    }
    return { success: true };
  }
}