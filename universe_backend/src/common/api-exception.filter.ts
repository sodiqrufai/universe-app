import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
import * as Sentry from '@sentry/node';

/**
 * One consistent error shape for the whole API:
 *   { success:false, statusCode, message, error:<human message> }
 *
 * Why: NestJS's default error body is {statusCode, message, error:"Forbidden"}
 * where `error` is only the status-text. The mobile app reads data['error'] to
 * show the user a message, so users were seeing "Forbidden" / "Payload Too
 * Large" instead of something useful. Here `error` always carries a readable
 * sentence, and `message` is kept for anything already reading it.
 */
@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('Http');

  catch(exception: unknown, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse();
    const req = host.switchToHttp().getRequest();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Something went wrong on our side. Please try again.';
    let extra: Record<string, any> = {};

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body = exception.getResponse();
      if (typeof body === 'string') {
        message = body;
      } else if (body && typeof body === 'object') {
        const b = body as Record<string, any>;
        const raw = b.message ?? b.error;
        message = Array.isArray(raw) ? raw.join(', ') : String(raw ?? exception.message);
        // keep any custom fields a controller attached (e.g. restricted flags)
        const { statusCode, message: _m, error: _e, ...rest } = b;
        extra = rest;
      }

      if (status === HttpStatus.TOO_MANY_REQUESTS) {
        message = 'Too many requests. Please wait a few seconds and try again.';
      } else if (status === HttpStatus.PAYLOAD_TOO_LARGE) {
        message = 'That file is too large. Please choose a smaller one.';
      } else if (status === HttpStatus.UNAUTHORIZED && /invalid|missing/i.test(message)) {
        message = 'Your session has expired. Please log in again.';
      }
    } else {
      // Unexpected error: log + report, never leak internals to the client.
      const err = exception as Error;
      this.logger.error(`${req?.method} ${req?.url} -> ${err?.message}`, err?.stack);
      Sentry.captureException(exception);
    }

    if (res.headersSent) return;
    res.status(status).json({ ...extra, success: false, statusCode: status, message, error: message });
  }
}
