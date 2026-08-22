import { Body, Controller, Delete, Get, Headers, Param, Post, Query, UnauthorizedException, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('education')
export class EducationController {
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

  @Get('courses')
  async getCourses(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: profile } = await this.supabase.client
      .from('profiles')
      .select('department_id')
      .eq('id', user.id)
      .single();

    if (!profile?.department_id) {
      return { success: true, courses: [] };
    }

    const { data, error } = await this.supabase.client
      .from('courses')
      .select('*')
      .eq('department_id', profile.department_id)
      .order('name');

    if (error) return { success: false, error: error.message };
    return { success: true, courses: data };
  }

  @Get('courses/:id/resources')
  async getResources(
    @Headers('authorization') authHeader: string,
    @Param('id') courseId: string,
    @Query('type') type?: string,
    @Query('search') search?: string,
  ) {
    await this.getUserFromToken(authHeader);

    let query = this.supabase.client
      .from('resources')
      .select('*, profiles(full_name, username)')
      .eq('course_id', courseId)
      .order('created_at', { ascending: false });

    if (type) query = query.eq('resource_type', type);
    if (search) query = query.ilike('title', `%${search}%`);

    const { data, error } = await query;
    if (error) return { success: false, error: error.message };
    return { success: true, resources: data };
  }

  @Post('courses/:id/resources')
  @UseInterceptors(FileInterceptor('file'))
  async uploadResource(
    @Headers('authorization') authHeader: string,
    @Param('id') courseId: string,
    @UploadedFile() file: any,
    @Body() body: { title: string; resourceType: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!file) return { success: false, error: 'No file provided' };
    if (!body.title?.trim()) return { success: false, error: 'Title is required' };

    const filePath = `${courseId}/${Date.now()}-${file.originalname}`;

    const { error: uploadError } = await this.supabase.client.storage
      .from('resources')
      .upload(filePath, file.buffer, { contentType: file.mimetype });

    if (uploadError) return { success: false, error: uploadError.message };

    const { data: urlData } = this.supabase.client.storage.from('resources').getPublicUrl(filePath);

    const resourceType = ['note', 'past_question', 'slide', 'other'].includes(body.resourceType)
      ? body.resourceType
      : 'note';

    const { data, error } = await this.supabase.client
      .from('resources')
      .insert({
        course_id: courseId,
        uploader_id: user.id,
        title: body.title.trim(),
        resource_type: resourceType,
        file_path: urlData.publicUrl,
      })
      .select()
      .single();

    if (error) return { success: false, error: error.message };
    return { success: true, resource: data };
  }

  @Get('courses/:id/groups')
  async getGroups(@Headers('authorization') authHeader: string, @Param('id') courseId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('study_groups')
      .select('*, study_group_members(user_id)')
      .eq('course_id', courseId)
      .order('created_at', { ascending: false });

    if (error) return { success: false, error: error.message };

    const enriched = (data ?? []).map((g: any) => ({
      ...g,
      memberCount: g.study_group_members?.length ?? 0,
      isMember: g.study_group_members?.some((m: any) => m.user_id === user.id) ?? false,
    }));

    return { success: true, groups: enriched };
  }

  @Post('courses/:id/groups')
  async createGroup(
    @Headers('authorization') authHeader: string,
    @Param('id') courseId: string,
    @Body() body: { name: string; description?: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.name?.trim()) return { success: false, error: 'Group name is required' };

    const { data: group, error } = await this.supabase.client
      .from('study_groups')
      .insert({
        course_id: courseId,
        name: body.name.trim(),
        description: body.description?.trim() ?? null,
        created_by: user.id,
      })
      .select()
      .single();

    if (error) return { success: false, error: error.message };

    await this.supabase.client
      .from('study_group_members')
      .insert({ study_group_id: group.id, user_id: user.id });

    return { success: true, group };
  }

  @Post('groups/:id/join')
  async joinGroup(@Headers('authorization') authHeader: string, @Param('id') groupId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('study_group_members')
      .insert({ study_group_id: groupId, user_id: user.id });

    if (error) {
      if (error.code === '23505') return { success: true }; // already a member, treat as success
      return { success: false, error: error.message };
    }
    return { success: true };
  }

  @Delete('groups/:id/leave')
  async leaveGroup(@Headers('authorization') authHeader: string, @Param('id') groupId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('study_group_members')
      .delete()
      .eq('study_group_id', groupId)
      .eq('user_id', user.id);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Get('groups/:id/members')
  async getMembers(@Headers('authorization') authHeader: string, @Param('id') groupId: string) {
    await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('study_group_members')
      .select('*, profiles(full_name, username, avatar_url)')
      .eq('study_group_id', groupId);

    if (error) return { success: false, error: error.message };
    return { success: true, members: data };
  }

  @Delete('groups/:id')
  async deleteGroup(@Headers('authorization') authHeader: string, @Param('id') groupId: string) {
    const user = await this.getUserFromToken(authHeader);
    console.log('Attempting delete. groupId:', groupId, 'user.id:', user.id);

    const { data: deleted, error } = await this.supabase.client
      .from('study_groups')
      .delete()
      .eq('id', groupId)
      .eq('created_by', user.id)
      .select();

    console.log('Delete result — deleted:', deleted, 'error:', error);

    if (error) return { success: false, error: error.message };
    if (!deleted || deleted.length === 0) {
      return { success: false, error: 'Group not found or you are not the creator' };
    }
    return { success: true };
  }
}