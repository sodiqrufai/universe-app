import { Body, Controller, Delete, Get, Headers, Param, Post, UnauthorizedException, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { SupabaseService } from '../supabase/supabase.service';

@Controller('chat')
export class ChatController {
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

  // Find or create a 1:1 conversation with another user.
  @Post('direct')
  async startDirectConversation(
    @Headers('authorization') authHeader: string,
    @Body() body: { otherUserId: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.otherUserId || body.otherUserId === user.id) {
      return { success: false, error: 'Invalid recipient' };
    }

    // Check if they've blocked each other.
    const { data: blocked } = await this.supabase.client
      .from('blocked_users')
      .select('id')
      .or(`and(blocker_id.eq.${user.id},blocked_id.eq.${body.otherUserId}),and(blocker_id.eq.${body.otherUserId},blocked_id.eq.${user.id})`)
      .maybeSingle();

    if (blocked) {
      return { success: false, error: 'Cannot start a conversation with this user' };
    }

    // Find an existing direct conversation between these two exact users.
    const { data: myConvos } = await this.supabase.client
      .from('conversation_participants')
      .select('conversation_id')
      .eq('user_id', user.id);

    const myConvoIds = (myConvos ?? []).map((c) => c.conversation_id);

    if (myConvoIds.length > 0) {
      const { data: sharedConvos } = await this.supabase.client
        .from('conversation_participants')
        .select('conversation_id, conversations!inner(is_group)')
        .eq('user_id', body.otherUserId)
        .in('conversation_id', myConvoIds);

      const existing = (sharedConvos ?? []).find((c: any) => c.conversations?.is_group === false);
      if (existing) {
        return { success: true, conversationId: existing.conversation_id };
      }
    }

    // No existing direct conversation — create one.
    const { data: convo, error: convoError } = await this.supabase.client
      .from('conversations')
      .insert({ is_group: false, created_by: user.id })
      .select()
      .single();

    if (convoError) return { success: false, error: convoError.message };

    await this.supabase.client.from('conversation_participants').insert([
      { conversation_id: convo.id, user_id: user.id },
      { conversation_id: convo.id, user_id: body.otherUserId },
    ]);

    return { success: true, conversationId: convo.id };
  }

  @Post('group')
  async createGroupConversation(
    @Headers('authorization') authHeader: string,
    @Body() body: { name: string; participantIds: string[] },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.name?.trim()) return { success: false, error: 'Group name is required' };

    const { data: convo, error } = await this.supabase.client
      .from('conversations')
      .insert({ is_group: true, name: body.name.trim(), created_by: user.id })
      .select()
      .single();

    if (error) return { success: false, error: error.message };

    const participantRows = [
      { conversation_id: convo.id, user_id: user.id },
      ...(body.participantIds ?? []).map((id) => ({ conversation_id: convo.id, user_id: id })),
    ];
    await this.supabase.client.from('conversation_participants').insert(participantRows);

    return { success: true, conversationId: convo.id };
  }

  @Get('inbox')
  async getInbox(@Headers('authorization') authHeader: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: myParticipations, error } = await this.supabase.client
      .from('conversation_participants')
      .select('conversation_id, last_read_at, conversations(id, is_group, name)')
      .eq('user_id', user.id);

    if (error) return { success: false, error: error.message };

    const results: any[] = [];
    for (const p of myParticipations ?? []) {
      const convo: any = p.conversations;
      if (!convo) continue;

      const { data: lastMessage } = await this.supabase.client
        .from('messages')
        .select('content, attachment_url, created_at, sender_id')
        .eq('conversation_id', convo.id)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      let displayName = convo.name;
      let otherAvatar: string | null = null;
      if (!convo.is_group) {
        const { data: otherParticipant } = await this.supabase.client
          .from('conversation_participants')
          .select('user_id, profiles(full_name, avatar_url)')
          .eq('conversation_id', convo.id)
          .neq('user_id', user.id)
          .maybeSingle();
        displayName = (otherParticipant?.profiles as any)?.full_name ?? 'Student';
        otherAvatar = (otherParticipant?.profiles as any)?.avatar_url ?? null;
      }

      const unread = lastMessage &&
        lastMessage.sender_id !== user.id &&
        (!p.last_read_at || new Date(lastMessage.created_at) > new Date(p.last_read_at));

      results.push({
        conversationId: convo.id,
        isGroup: convo.is_group,
        name: displayName,
        avatarUrl: otherAvatar,
        lastMessage: lastMessage?.content ?? (lastMessage?.attachment_url ? '📎 Attachment' : null),
        lastMessageAt: lastMessage?.created_at ?? null,
        unread: !!unread,
      });
    }

    results.sort((a, b) => {
      if (!a.lastMessageAt) return 1;
      if (!b.lastMessageAt) return -1;
      return new Date(b.lastMessageAt).getTime() - new Date(a.lastMessageAt).getTime();
    });

    return { success: true, conversations: results };
  }

  @Get(':id/messages')
  async getMessages(@Headers('authorization') authHeader: string, @Param('id') conversationId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { data: participant } = await this.supabase.client
      .from('conversation_participants')
      .select('id')
      .eq('conversation_id', conversationId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (!participant) {
      return { success: false, error: 'You are not part of this conversation' };
    }

    const { data, error } = await this.supabase.client
      .from('messages')
      .select('*, profiles(full_name, avatar_url)')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true });

    if (error) return { success: false, error: error.message };

    await this.supabase.client
      .from('conversation_participants')
      .update({ last_read_at: new Date().toISOString() })
      .eq('conversation_id', conversationId)
      .eq('user_id', user.id);

    return { success: true, messages: data };
  }

  @Post(':id/messages')
  @UseInterceptors(FileInterceptor('attachment'))
  async sendMessage(
    @Headers('authorization') authHeader: string,
    @Param('id') conversationId: string,
    @UploadedFile() file: any,
    @Body() body: { content: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    const { data: participant } = await this.supabase.client
      .from('conversation_participants')
      .select('id')
      .eq('conversation_id', conversationId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (!participant) {
      return { success: false, error: 'You are not part of this conversation' };
    }

    if (!body.content?.trim() && !file) {
      return { success: false, error: 'Message cannot be empty' };
    }

    let attachmentUrl: string | null = null;
    if (file) {
      const filePath = `${conversationId}/${Date.now()}-${file.originalname}`;
      const { error: uploadError } = await this.supabase.client.storage
        .from('chat-attachments')
        .upload(filePath, file.buffer, { contentType: file.mimetype });
      if (!uploadError) {
        const { data: urlData } = this.supabase.client.storage.from('chat-attachments').getPublicUrl(filePath);
        attachmentUrl = urlData.publicUrl;
      }
    }

    const { data, error } = await this.supabase.client
      .from('messages')
      .insert({
        conversation_id: conversationId,
        sender_id: user.id,
        content: body.content?.trim() || null,
        attachment_url: attachmentUrl,
      })
      .select('*, profiles(full_name, avatar_url)')
      .single();

    if (error) return { success: false, error: error.message };

    await this.supabase.client
      .from('conversation_participants')
      .update({ last_read_at: new Date().toISOString() })
      .eq('conversation_id', conversationId)
      .eq('user_id', user.id);

    return { success: true, message: data };
  }

  @Post('block/:userId')
  async blockUser(@Headers('authorization') authHeader: string, @Param('userId') blockedId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('blocked_users')
      .insert({ blocker_id: user.id, blocked_id: blockedId });

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Delete('block/:userId')
  async unblockUser(@Headers('authorization') authHeader: string, @Param('userId') blockedId: string) {
    const user = await this.getUserFromToken(authHeader);

    const { error } = await this.supabase.client
      .from('blocked_users')
      .delete()
      .eq('blocker_id', user.id)
      .eq('blocked_id', blockedId);

    if (error) return { success: false, error: error.message };
    return { success: true };
  }

  @Post('report')
  async reportChat(
    @Headers('authorization') authHeader: string,
    @Body() body: { conversationId?: string; reportedUserId?: string; reason: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    if (!body.reason?.trim()) return { success: false, error: 'Reason required' };

    const { error } = await this.supabase.client.from('chat_reports').insert({
      conversation_id: body.conversationId ?? null,
      reported_user_id: body.reportedUserId ?? null,
      reported_by: user.id,
      reason: body.reason.trim(),
    });

    if (error) return { success: false, error: error.message };
    return { success: true };
  }
}