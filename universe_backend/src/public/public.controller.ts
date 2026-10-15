import { Body, Controller, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { SupabaseService } from '../supabase/supabase.service';

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

// Endpoints used by the public marketing landing page. No auth: callers are
// anonymous visitors, so everything is validated, throttled per IP, and
// written with the backend's service-role client only.
@Controller('public')
export class PublicController {
  constructor(private readonly supabase: SupabaseService) {}

  @Throttle({ default: { limit: 5, ttl: 60000 } })
  @Post('waitlist')
  async joinWaitlist(@Body() body: { email?: string; universityId?: string }) {
    const email = body.email?.trim().toLowerCase();
    if (!email || email.length > 254 || !EMAIL_RE.test(email)) {
      return { success: false, error: 'Enter a valid email address.' };
    }
    if (!body.universityId) {
      return { success: false, error: 'Pick your university first.' };
    }

    const { data: uni } = await this.supabase.client
      .from('universities')
      .select('id, name, is_pilot')
      .eq('id', body.universityId)
      .maybeSingle();
    if (!uni) return { success: false, error: 'University not found.' };
    if (uni.is_pilot) {
      return { success: false, error: `UniVerse is already live at ${uni.name} — no waitlist needed.` };
    }

    const { error } = await this.supabase.client
      .from('waitlist_signups')
      .upsert({ email, university_id: uni.id }, { onConflict: 'email,university_id', ignoreDuplicates: true });
    if (error) return { success: false, error: 'Could not save your signup. Please try again.' };
    return { success: true, universityName: uni.name };
  }

  @Throttle({ default: { limit: 3, ttl: 60000 } })
  @Post('inquiry')
  async partnerInquiry(
    @Body() body: { name?: string; organization?: string; email?: string; message?: string },
  ) {
    const name = body.name?.trim();
    const email = body.email?.trim().toLowerCase();
    const message = body.message?.trim();
    if (!name || name.length > 120) return { success: false, error: 'Enter your name.' };
    if (!email || email.length > 254 || !EMAIL_RE.test(email)) {
      return { success: false, error: 'Enter a valid email address.' };
    }
    if (!message || message.length < 10 || message.length > 2000) {
      return { success: false, error: 'Write a short message (10–2000 characters).' };
    }

    const { error } = await this.supabase.client.from('partner_inquiries').insert({
      name,
      organization: body.organization?.trim().slice(0, 160) || null,
      email,
      message,
    });
    if (error) return { success: false, error: 'Could not send your message. Please try again.' };
    return { success: true };
  }
}
