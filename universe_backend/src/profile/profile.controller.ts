import { Body, Controller, Get, Headers, Patch, Post, UnauthorizedException, UploadedFile, UseInterceptors } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { FileInterceptor } from '@nestjs/platform-express';


@Controller('profile')
export class ProfileController {
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

  @Patch('update')
  async updateProfile(
    @Headers('authorization') authHeader: string,
    @Body() body: {
      universityId?: string;
      facultyId?: string;
      departmentId?: string;
      level?: string;
      fullName?: string;
      username?: string;
      bio?: string;
    },
  ) {
    const user = await this.getUserFromToken(authHeader);

    const updates: Record<string, any> = { updated_at: new Date().toISOString() };
    if (body.universityId) updates.university_id = body.universityId;
    if (body.facultyId) updates.faculty_id = body.facultyId;
    if (body.departmentId) updates.department_id = body.departmentId;
    if (body.level) updates.level = body.level;
    if (body.fullName !== undefined) updates.full_name = body.fullName;
    if (body.username !== undefined) updates.username = body.username;
    if (body.bio !== undefined) updates.bio = body.bio;

    const { error } = await this.supabase.client
      .from('profiles')
      .upsert({ id: user.id, ...updates });

    if (error) {
      return { success: false, error: error.message };
    }
    return { success: true };
  }

  @Get('me')
  async getMyProfile(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('profiles')
      .select('*, universities(name), faculties(name), departments(name)')
      .eq('id', user.id)
      .single();

    if (error) {
      return { success: false, error: error.message };
    }
    return { success: true, profile: data };
  }
  
    @Post('avatar')
  @UseInterceptors(FileInterceptor('file'))
  async uploadAvatar(
    @Headers('authorization') authHeader: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!file) {
      return { success: false, error: 'No file provided' };
    }

    const filePath = `${user.id}/avatar.jpg`;

    const { error: uploadError } = await this.supabase.client.storage
      .from('avatars')
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: true,
      });

    if (uploadError) {
      return { success: false, error: uploadError.message };
    }

    const { data: urlData } = this.supabase.client.storage
      .from('avatars')
      .getPublicUrl(filePath);

    await this.supabase.client
      .from('profiles')
      .upsert({ id: user.id, avatar_url: urlData.publicUrl, updated_at: new Date().toISOString() });

    return { success: true, avatarUrl: urlData.publicUrl };
  }
}