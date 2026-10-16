import { ForbiddenException, HttpStatus, NotFoundException, PayloadTooLargeException } from '@nestjs/common';
import { ThrottlerException } from '@nestjs/throttler';
import { ApiExceptionFilter } from './api-exception.filter';

function run(exception: unknown) {
  const filter = new ApiExceptionFilter();
  let status = 0;
  let body: any;
  const res = { headersSent: false, status: (s: number) => { status = s; return res; }, json: (b: any) => { body = b; } };
  const host: any = { switchToHttp: () => ({ getResponse: () => res, getRequest: () => ({ method: 'GET', url: '/x' }) }) };
  jest.spyOn((filter as any).logger, 'error').mockImplementation(() => undefined);
  filter.catch(exception, host);
  return { status, body };
}

describe('ApiExceptionFilter', () => {
  it('puts a readable sentence in `error` (the field the app displays), not "Forbidden"', () => {
    const { status, body } = run(new ForbiddenException('Your account has been suspended.'));
    expect(status).toBe(403);
    expect(body).toMatchObject({ success: false, statusCode: 403, message: 'Your account has been suspended.', error: 'Your account has been suspended.' });
  });
  it('joins validation message arrays', () => {
    const { body } = run(new (require('@nestjs/common').BadRequestException)({ message: ['a is bad', 'b is bad'] }));
    expect(body.error).toBe('a is bad, b is bad');
  });
  it('turns rate limiting into a friendly 429', () => {
    const { status, body } = run(new ThrottlerException());
    expect(status).toBe(HttpStatus.TOO_MANY_REQUESTS);
    expect(body.error).toMatch(/Too many requests/);
  });
  it('turns payload-too-large into a friendly 413', () => {
    const { status, body } = run(new PayloadTooLargeException('File too large'));
    expect(status).toBe(413);
    expect(body.error).toMatch(/too large/);
  });
  it('keeps 404s as 404s', () => {
    expect(run(new NotFoundException('Nope')).status).toBe(404);
  });
  it('never leaks internals of unexpected errors', () => {
    const { status, body } = run(new Error('connect ECONNREFUSED 10.0.0.5:5432 password=hunter2'));
    expect(status).toBe(500);
    expect(JSON.stringify(body)).not.toMatch(/ECONNREFUSED|hunter2|10\.0\.0\.5/);
    expect(body.success).toBe(false);
  });
});
