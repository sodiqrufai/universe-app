import { Controller, Get, Query } from '@nestjs/common';
import { AppService } from './app.service';
import { SupabaseService } from './supabase/supabase.service';


@Controller()
export class AppController {
  constructor(
    private readonly appService: AppService,
    private readonly supabase: SupabaseService,
  ) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('health/db')
  async checkDb() {
    const { data, error } = await this.supabase.client.auth.admin.listUsers();
    if (error) {
      return { connected: false, error: error.message };
    }
    return { connected: true, userCount: data.users.length };
  }

  @Get('universities')
  async getUniversities() {
    const { data, error } = await this.supabase.client
      .from('universities')
      .select('id, name, short_name, city, ownership_type')
      .eq('is_active', true)
      .order('name');

    if (error) {
      return { error: error.message };
    }
    return data;
  }

    @Get('faculties')
  async getFaculties(@Query('universityId') universityId: string) {
    const { data, error } = await this.supabase.client
      .from('faculties')
      .select('id, name')
      .eq('university_id', universityId)
      .order('name');
    if (error) return { error: error.message };
    return data;
  }

  @Get('departments')
  async getDepartments(@Query('facultyId') facultyId: string) {
    const { data, error } = await this.supabase.client
      .from('departments')
      .select('id, name')
      .eq('faculty_id', facultyId)
      .order('name');
    if (error) return { error: error.message };
    return data;
  }
}