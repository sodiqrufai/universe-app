import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { SupabaseModule } from './supabase/supabase.module';
import { AuthController } from './auth/auth.controller';
import { ProfileController } from './profile/profile.controller';
import { VerificationController } from './verification/verification.controller';
import { AdminController } from './admin/admin.controller';
import { HomeController } from './home/home.controller';
import { PostsController } from './posts/posts.controller';
import { AnonymousController } from './anonymous/anonymous.controller';
import { EducationController } from './education/education.controller';
import { MarketplaceController } from './marketplace/marketplace.controller';
import { ServicesController } from './services/services.controller';
import { EventsController } from './events/events.controller';
import { ChatController } from './chat/chat.controller';
import { NotificationsController } from './notifications/notifications.controller';
import { NotificationsService } from './notifications/notifications.service';
import { StoriesController } from './stories/stories.controller';
import { LegalController } from './legal/legal.controller';
import { SearchController } from './search/search.controller';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    SupabaseModule,
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 30 }]), // 30 requests/min default, override per-route below
  ],
  controllers: [AppController, AuthController, ProfileController, VerificationController, AdminController, HomeController, PostsController, AnonymousController, EducationController, MarketplaceController, ServicesController, EventsController, ChatController, NotificationsController, StoriesController, LegalController, SearchController],
  providers: [AppService, NotificationsService,
  { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule {}