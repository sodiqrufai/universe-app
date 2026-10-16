import './instrument';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { Logger, ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { ApiExceptionFilter } from './common/api-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const logger = new Logger('Bootstrap');

  // Render (and most hosts) put a proxy in front of the app. Without this,
  // req.ip is the proxy's address, so EVERY user would share one rate-limit bucket.
  app.set('trust proxy', 1);

  // The API also serves two small HTML pages (email confirmed / reset password)
  // that use inline script+style, so CSP is off; the other helmet protections stay on.
  app.use(
    helmet({
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  // CORS: set ALLOWED_ORIGINS (comma-separated, e.g. https://universe.netlify.app)
  // on Render to lock the API to your sites. If it is NOT set we stay open so a
  // missing env var can never take the app down — but we warn loudly.
  const allowed = (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((o) => o.trim().replace(/\/$/, ''))
    .filter(Boolean);
  if (allowed.length === 0) {
    logger.warn('ALLOWED_ORIGINS is not set — CORS is open to every origin. Set it before public launch.');
    app.enableCors();
  } else {
    app.enableCors({
      origin: (origin, cb) => {
        // no Origin header = mobile app / curl / server-to-server: allow
        if (!origin) return cb(null, true);
        const o = origin.replace(/\/$/, '');
        const isLocal = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(o);
        cb(null, isLocal || allowed.includes(o));
      },
      credentials: false,
    });
  }

  // Validates typed DTO bodies (used by newer endpoints). Controllers that still
  // take plain inline types are untouched.
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.useGlobalFilters(new ApiExceptionFilter());
  app.enableShutdownHooks();

  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}
bootstrap();
