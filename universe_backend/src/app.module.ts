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

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    SupabaseModule,
  ],
  controllers: [AppController, AuthController, ProfileController, VerificationController, AdminController, HomeController, PostsController],
  providers: [AppService],
})
export class AppModule {}