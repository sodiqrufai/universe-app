import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Query, UnauthorizedException, UploadedFiles, UseInterceptors } from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('services')
export class ServicesController {
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
      .from('service_categories')
      .select('*')
      .order('name');
    if (error) return { success: false, error: error.message };
    return { success: true, categories: data };
  }

  @Get('listings')
  async getServices(
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

    let query = this.supabase.client
      .from('services')
      .select('*, profiles(full_name, username, avatar_url), service_images(image_url, sort_order)')
      .eq('status', 'active')
      .order('created_at', { ascending: false });

    if (profile?.university_id) query = query.eq('university_id', profile.university_id);
    if (categoryId) query = query.eq('category_id', categoryId);
    if (search) query = query.textSearch('search_vector', search, { type: 'websearch', config: 'english' });

    const { data, error } = await query;
    if (error) return { success: false, error: error.message };
    return { success: true, services: data };
  }

  @Get('listings/:id')
  async getService(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('services')
      .select('*, profiles(full_name, username, avatar_url), service_images(image_url, sort_order)')
      .eq('id', id)
      .single();

    if (error) return { success: false, error: error.message };
    return { success: true, service: data };
  }

  @Post('listings')
  @UseInterceptors(FilesInterceptor('images', 6))
  async createService(
    @Headers('authorization') authHeader: string,
    @UploadedFiles() files: any[],
    @Body() body: { title: string; description: string; price: string; priceType: string; categoryId: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

    if (!body.title?.trim()) return { success: false, error: 'Title is required' };

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('university_id')
      .eq('id', user.id)
      .single();

    const priceType = ['fixed', 'hourly', 'negotiable'].includes(body.priceType) ? body.priceType : 'fixed';

    const { data: service, error } = await this.supabase.client
      .from('services')
      .insert({
        provider_id: user.id,
        category_id: body.categoryId || null,
        university_id: profile?.university_id ?? null,
        title: body.title.trim(),
        description: body.description?.trim() ?? null,
        price: body.price ? parseFloat(body.price) : null,
        price_type: priceType,
      })
      .select()
      .single();

    if (error) return { success: false, error: error.message };

    if (files && files.length > 0) {
      for (let i = 0; i < files.length; i++) {
        const filePath = `${user.id}/${service.id}/${Date.now()}-${i}.jpg`;
        const { error: uploadError } = await this.supabase.client.storage
          .from('service-images')
          .upload(filePath, files[i].buffer, { contentType: files[i].mimetype });
        if (!uploadError) {
          const { data: urlData } = this.supabase.client.storage.from('service-images').getPublicUrl(filePath);
          await this.supabase.client
            .from('service_images')
            .insert({ service_id: service.id, image_url: urlData.publicUrl, sort_order: i });
        }
      }
    }

    return { success: true, service };
  }

  @Post('listings/:id/book')
  async createBooking(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { message: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('service_bookings')
      .insert({ service_id: id, customer_id: user.id, message: body.message?.trim() ?? null })
      .select()
      .single();

    if (error) return { success: false, error: error.message };
    return { success: true, booking: data };
  }

  @Get('bookings')
  async getMyBookings(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: asCustomer, error: e1 } = await this.supabase.client
      .from('service_bookings')
      .select('*, services(title, provider_id, profiles(full_name))')
      .eq('customer_id', user.id)
      .order('created_at', { ascending: false });

    const { data: myServices } = await this.supabase.client
      .from('services')
      .select('id')
      .eq('provider_id', user.id);

    const myServiceIds = (myServices ?? []).map((s) => s.id);
    let asProvider: any[] = [];
    if (myServiceIds.length > 0) {
      const { data } = await this.supabase.client
        .from('service_bookings')
        .select('*, services(title), profiles(full_name)')
        .in('service_id', myServiceIds)
        .order('created_at', { ascending: false });
      asProvider = data ?? [];
    }

    if (e1) return { success: false, error: e1.message };
    return { success: true, asCustomer: asCustomer ?? [], asProvider };
  }

  @Patch('bookings/:id')
  async respondToBooking(
    @Headers('authorization') authHeader: string,
    @Param('id') id: string,
    @Body() body: { status: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!['accepted', 'rejected', 'completed'].includes(body.status)) {
      return { success: false, error: 'Invalid status' };
    }

    const { data: booking } = await this.supabase.client
      .from('service_bookings')
      .select('service_id, services(provider_id)')
      .eq('id', id)
      .single();

    if (!booking || (booking.services as any)?.provider_id !== user.id) {
      return { success: false, error: 'You are not the provider of this service' };
    }

    const { error } = await this.supabase.client
      .from('service_bookings')
      .update({ status: body.status, updated_at: new Date().toISOString() })
      .eq('id', id);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Post('listings/:id/report')
  async reportService(@Headers('authorization') authHeader: string, @Param('id') id: string, @Body() body: { reason: string }) {
    const user = await this.getUserFromToken(authHeader);
    if (!body.reason?.trim()) return { success: false, error: 'Reason required' };

    const { data: service } = await this.supabase.client.from('services').select('provider_id').eq('id', id).single();
    const { error } = await this.supabase.client
      .from('reports')
      .insert({ target_type: 'service', target_id: id, reported_user_id: service?.provider_id ?? null, reported_by: user.id, reason: body.reason.trim() });
    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Delete('listings/:id')
  async deleteService(@Headers('authorization') authHeader: string, @Param('id') id: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: deleted, error } = await this.supabase.client
      .from('services')
      .delete()
      .eq('id', id)
      .eq('provider_id', user.id)
      .select();

    if (error) return { success: false, error: error.message };
    if (!deleted || deleted.length === 0) {
      return { success: false, error: 'Service not found or not yours' };
    }
    return { success: true };
  }
}