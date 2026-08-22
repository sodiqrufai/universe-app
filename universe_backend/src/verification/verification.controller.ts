import { Body, Controller, Get, Headers, Post, UnauthorizedException, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('verification')
export class VerificationController {
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

  @Post('submit')
  @UseInterceptors(FileInterceptor('file'))
  async submit(
    @Headers('authorization') authHeader: string,
    @UploadedFile() file: any,
    @Body() body: { fullName: string; matricNumber: string; universityId: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!file) {
      return { success: false, error: 'No document provided' };
    }
    if (!body.fullName || !body.matricNumber || !body.universityId) {
      return { success: false, error: 'Missing required fields' };
    }

    const filePath = `${user.id}/id-document.jpg`;

    const { error: uploadError } = await this.supabase.client.storage
      .from('verification-docs')
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: true,
      });

    if (uploadError) {
      console.error('Upload error:', uploadError);
      return { success: false, error: uploadError.message };
    }

    const { data: existing } = await this.supabase.client
      .from('verifications')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (existing) {
      const { error: updateError } = await this.supabase.client
        .from('verifications')
        .update({
          full_name: body.fullName,
          matric_number: body.matricNumber,
          university_id: body.universityId,
          document_path: filePath,
          status: 'pending',
          rejection_reason: null,
          reviewed_by: null,
          reviewed_at: null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', existing.id);

      if (updateError) {
        console.error('Update error:', updateError);
        return { success: false, error: updateError.message };
      }
      return { success: true };
    }

    const { error: insertError } = await this.supabase.client
      .from('verifications')
      .insert({
        user_id: user.id,
        full_name: body.fullName,
        matric_number: body.matricNumber,
        university_id: body.universityId,
        document_path: filePath,
        status: 'pending',
      });

    if (insertError) {
      console.error('Insert error:', insertError);
      return { success: false, error: insertError.message };
    }

    return { success: true };
  }

  @Get('status')
  async getStatus(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data, error } = await this.supabase.client
      .from('verifications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error) {
      return { success: false, error: error.message };
    }
    return { success: true, verification: data };
  }
}