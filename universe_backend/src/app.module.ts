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

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    SupabaseModule,
  ],
  controllers: [AppController, AuthController, ProfileController, VerificationController, AdminController, HomeController, PostsController, AnonymousController, EducationController, MarketplaceController, ServicesController, EventsController, ChatController],
  providers: [AppService],
})
export class AppModule {}