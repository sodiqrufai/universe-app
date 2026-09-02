import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Param,
  Post,
  UnauthorizedException,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { SupabaseService } from '../supabase/supabase.service';
import { NotificationsService } from '../notifications/notifications.service';

@Controller('chat')
export class ChatController {
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

  @Post('direct')
  async startDirectConversation(
    @Headers('authorization') authHeader: string,
    @Body() body: { otherUserId: string },
  ) {
    const user = await this.getUserFromToken(authHeader);

    if (!body.otherUserId || body.otherUserId === user.id) {
      return { success: false, error: 'Invalid recipient' };
    }

    const { data: blocked } = await this.supabase.client
      .from('blocked_users')
      .select('id')
      .or(
        `and(blocker_id.eq.${user.id},blocked_id.eq.${body.otherUserId}),and(blocker_id.eq.${body.otherUserId},blocked_id.eq.${user.id})`,
      )
      .maybeSingle();

    if (blocked) {
      return { success: false, error: 'Cannot start a conversation with this user' };
    }

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
        // If I'd previously "deleted" (soft-left) this conversation, tapping
        // Message on the same person should bring it back into my inbox again.
        await this.supabase.client
          .from('conversation_participants')
          .update({ left_at: null })
          .eq('conversation_id', existing.conversation_id)
          .eq('user_id', user.id);

        return { success: true, conversationId: existing.conversation_id };
      }
    }

    const { data: convo, error: convoError } = await this.supabase.client
      .from('conversations')
      .insert({ is_group: false, created_by: user.id })
      .select()
      .single();

    if (convoError) {
      return { success: false, error: convoError.message };
    }

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

    if (!body.name?.trim()) {
      return { success: false, error: 'Group name is required' };
    }

    const { data: convo, error } = await this.supabase.client
      .from('conversations')
      .insert({ is_group: true, name: body.name.trim(), created_by: user.id })
      .select()
      .single();

    if (error) {
      return { success: false, error: error.message };
    }

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
      .select('conversation_id, last_read_at, left_at, conversations(id, is_group, name)')
      .eq('user_id', user.id);

    if (error) {
      return { success: false, error: error.message };
    }

    // Soft-deleted-by-me conversations stay fully intact in the database for
    // the other participant(s) -- they just disappear from MY inbox until a
    // new message arrives (sendMessage clears left_at for recipients) or I
    // message that person again (startDirectConversation clears it for me).
    const visibleParticipations = (myParticipations ?? []).filter((p) => !p.left_at);

    const convoIds = visibleParticipations.map((p) => p.conversation_id);

    if (convoIds.length === 0) {
      return { success: true, conversations: [] };
    }

    const { data: allMessages } = await this.supabase.client
      .from('messages')
      .select('conversation_id, content, attachment_url, media_type, created_at, sender_id')
      .in('conversation_id', convoIds)
      .order('created_at', { ascending: false });

    const lastMessageByConvo = new Map<string, any>();
    for (const message of allMessages ?? []) {
      if (!lastMessageByConvo.has(message.conversation_id)) {
        lastMessageByConvo.set(message.conversation_id, message);
      }
    }

    const { data: allOtherParticipants } = await this.supabase.client
      .from('conversation_participants')
      .select('conversation_id, user_id, profiles(full_name, avatar_url)')
      .in('conversation_id', convoIds)
      .neq('user_id', user.id);

    const otherByConvo = new Map<string, any>();
    for (const participant of allOtherParticipants ?? []) {
      if (!otherByConvo.has(participant.conversation_id)) {
        otherByConvo.set(participant.conversation_id, participant);
      }
    }

    const results = visibleParticipations
      .map((p) => {
        const convo: any = p.conversations;
        if (!convo) return null;

        const lastMessage = lastMessageByConvo.get(convo.id);

        let displayName = convo.name;
        let otherAvatar: string | null = null;

        if (!convo.is_group) {
          const other = otherByConvo.get(convo.id);
          displayName = (other?.profiles as any)?.full_name ?? 'Student';
          otherAvatar = (other?.profiles as any)?.avatar_url ?? null;
        }

        const unread =
          lastMessage &&
          lastMessage.sender_id !== user.id &&
          (!p.last_read_at || new Date(lastMessage.created_at) > new Date(p.last_read_at));

        const lastMessagePreview = lastMessage?.content
          ? lastMessage.content
          : lastMessage?.attachment_url
          ? lastMessage.media_type === 'audio'
            ? '🎤 Voice note'
            : '📎 Attachment'
          : null;

        return {
          conversationId: convo.id,
          isGroup: convo.is_group,
          name: displayName,
          avatarUrl: otherAvatar,
          lastMessage: lastMessagePreview,
          lastMessageAt: lastMessage?.created_at ?? null,
          unread: !!unread,
        };
      })
      .filter((r) => r !== null);

    results.sort((a: any, b: any) => {
      if (!a.lastMessageAt) return 1;
      if (!b.lastMessageAt) return -1;
      return new Date(b.lastMessageAt).getTime() - new Date(a.lastMessageAt).getTime();
    });

    return { success: true, conversations: results };
  }

  @Delete(':id')
  async deleteConversationForMe(
    @Headers('authorization') authHeader: string,
    @Param('id') conversationId: string,
  ) {
    const user = await this.getUserFromToken(authHeader);

    // Soft delete: only hides the conversation from MY inbox. The conversation
    // row, its messages, and the other participant's access are untouched.
    const { data: updated, error } = await this.supabase.client
      .from('conversation_participants')
      .update({ left_at: new Date().toISOString() })
      .eq('conversation_id', conversationId)
      .eq('user_id', user.id)
      .select();

    if (error) return { success: false, error: error.message };
    if (!updated || updated.length === 0) {
      return { success: false, error: 'You are not part of this conversation' };
    }
    return { success: true };
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

    if (error) {
      return { success: false, error: error.message };
    }

    await this.supabase.client
      .from('conversation_participants')
      .update({ last_read_at: new Date().toISOString() })
      .eq('conversation_id', conversationId)
      .eq('user_id', user.id);

    // Fetching messages is treated as the delivery-acknowledgement moment for
    // this client -- mark anything sent by the other participant(s) as
    // delivered if it hasn't been already. Kept separate from last_read_at
    // (delivery != read) per the spec.
    const undeliveredIds = (data ?? [])
      .filter((m: any) => m.sender_id !== user.id && !m.delivered_at)
      .map((m: any) => m.id);

    if (undeliveredIds.length > 0) {
      const deliveredAt = new Date().toISOString();
      await this.supabase.client
        .from('messages')
        .update({ delivered_at: deliveredAt })
        .in('id', undeliveredIds);
      for (const m of data ?? []) {
        if (undeliveredIds.includes(m.id)) m.delivered_at = deliveredAt;
      }
    }

    const messageIds = (data ?? []).map((m: any) => m.id);
    let reactionsByMessage: Record<string, { like: number; love: number }> = {};
    let myReactions: Record<string, Set<string>> = {};

    if (messageIds.length > 0) {
      const { data: reactions } = await this.supabase.client
        .from('message_reactions')
        .select('message_id, user_id, reaction_type')
        .in('message_id', messageIds);

      reactions?.forEach((r) => {
        if (!reactionsByMessage[r.message_id]) reactionsByMessage[r.message_id] = { like: 0, love: 0 };
        reactionsByMessage[r.message_id][r.reaction_type as 'like' | 'love']++;
        if (r.user_id === user.id) {
          if (!myReactions[r.message_id]) myReactions[r.message_id] = new Set();
          myReactions[r.message_id].add(r.reaction_type);
        }
      });
    }

    const enriched = (data ?? []).map((m: any) => ({
      ...m,
      reactionCounts: reactionsByMessage[m.id] ?? { like: 0, love: 0 },
      myReactions: Array.from(myReactions[m.id] ?? []),
    }));

    return { success: true, messages: enriched };
  }

  @Post(':id/messages')
  @UseInterceptors(FileInterceptor('attachment'))
  async sendMessage(
    @Headers('authorization') authHeader: string,
    @Param('id') conversationId: string,
    @UploadedFile() file: any,
    @Body() body: { content: string; mediaType?: string; durationSeconds?: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);

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
    // Voice notes use the same 'attachment' upload field as images; media_type
    // distinguishes them so the client knows how to render/play the result.
    const mediaType = file ? (body.mediaType === 'audio' ? 'audio' : 'image') : null;
    const durationSeconds = body.durationSeconds ? parseInt(body.durationSeconds, 10) : null;

    if (file) {
      const bucket = mediaType === 'audio' ? 'chat-voice-notes' : 'chat-attachments';
      const filePath = `${conversationId}/${Date.now()}-${file.originalname}`;

      const { error: uploadError } = await this.supabase.client.storage
        .from(bucket)
        .upload(filePath, file.buffer, { contentType: file.mimetype });

      if (uploadError) {
        console.error('Chat media upload error:', uploadError);
      } else {
        const { data: urlData } = this.supabase.client.storage.from(bucket).getPublicUrl(filePath);
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
        media_type: mediaType,
        duration_seconds: durationSeconds,
      })
      .select('*, profiles(full_name, avatar_url)')
      .single();

    if (error) {
      return { success: false, error: error.message };
    }

    await this.supabase.client
      .from('conversation_participants')
      .update({ last_read_at: new Date().toISOString() })
      .eq('conversation_id', conversationId)
      .eq('user_id', user.id);

    // A fresh message un-hides the conversation for anyone who'd soft-deleted
    // it, so they see the new activity instead of it staying silently gone.
    await this.supabase.client
      .from('conversation_participants')
      .update({ left_at: null })
      .eq('conversation_id', conversationId)
      .neq('user_id', user.id);

    const { data: otherParticipants } = await this.supabase.client
      .from('conversation_participants')
      .select('user_id')
      .eq('conversation_id', conversationId)
      .neq('user_id', user.id);

    const senderName = (data.profiles as any)?.full_name ?? 'Someone';

    for (const p of otherParticipants ?? []) {
      await this.notifications.create(
        p.user_id,
        'chat_message',
        senderName,
        body.content?.trim() || (mediaType === 'audio' ? '🎤 Sent a voice note' : '📎 Sent an attachment'),
        { conversationId },
      );
    }

    return { success: true, message: data };
  }

  @Post('messages/:id/react')
  async toggleMessageReaction(
    @Headers('authorization') authHeader: string,
    @Param('id') messageId: string,
    @Body() body: { reactionType?: string },
  ) {
    const user = await this.getUserFromToken(authHeader);
    await this.supabase.assertNotRestricted(user.id);
    const reactionType = body.reactionType === 'love' ? 'love' : 'like';

    const { data: message } = await this.supabase.client
      .from('messages')
      .select('conversation_id')
      .eq('id', messageId)
      .single();

    if (!message) return { success: false, error: 'Message not found' };

    const { data: participant } = await this.supabase.client
      .from('conversation_participants')
      .select('id')
      .eq('conversation_id', message.conversation_id)
      .eq('user_id', user.id)
      .maybeSingle();

    if (!participant) {
      return { success: false, error: 'You are not part of this conversation' };
    }

    const { data: existing } = await this.supabase.client
      .from('message_reactions')
      .select('id')
      .eq('message_id', messageId)
      .eq('user_id', user.id)
      .eq('reaction_type', reactionType)
      .maybeSingle();

    if (existing) {
      await this.supabase.client.from('message_reactions').delete().eq('id', existing.id);
      return { success: true, reacted: false, reactionType };
    } else {
      await this.supabase.client
        .from('message_reactions')
        .insert({ message_id: messageId, user_id: user.id, reaction_type: reactionType });
      return { success: true, reacted: true, reactionType };
    }
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

    if (!body.reason?.trim()) {
      return { success: false, error: 'Reason required' };
    }

    const { error } = await this.supabase.client.from('reports').insert({
      target_type: 'chat',
      target_id: body.conversationId ?? null,
      reported_user_id: body.reportedUserId ?? null,
      reported_by: user.id,
      reason: body.reason.trim(),
    });

    if (error) return { success: false, error: error.message };
    return { success: true };
  }
}
