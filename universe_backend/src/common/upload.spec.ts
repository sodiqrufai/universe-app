import { BadRequestException, PayloadTooLargeException } from '@nestjs/common';
import { assertFileWithinLimit, classifyFile, sanitizeFilename, uploadOptions, UPLOAD_RULES } from './upload';

const MB = 1024 * 1024;
const run = (opts: ReturnType<typeof uploadOptions>, file: any) =>
  new Promise<{ err: Error | null; ok: boolean }>((resolve) =>
    opts.fileFilter({}, file, (err, ok) => resolve({ err, ok })),
  );

describe('classifyFile', () => {
  it('recognises allowed types by MIME', () => {
    expect(classifyFile({ mimetype: 'image/png', originalname: 'a.png' }, ['image'])).toBe('image');
    expect(classifyFile({ mimetype: 'video/mp4', originalname: 'a.mp4' }, ['image', 'video'])).toBe('video');
  });
  it('rejects executables and mismatches', () => {
    expect(classifyFile({ mimetype: 'application/x-msdownload', originalname: 'virus.exe' }, ['image'])).toBeNull();
    expect(classifyFile({ mimetype: 'application/pdf', originalname: 'a.pdf' }, ['image'])).toBeNull();
    expect(classifyFile({ mimetype: 'text/html', originalname: 'a.jpg' }, ['image'])).toBeNull();
  });
  it('trusts the extension only when the client sent a generic MIME type', () => {
    expect(classifyFile({ mimetype: 'application/octet-stream', originalname: 'p.JPG' }, ['image'])).toBe('image');
    expect(classifyFile({ mimetype: 'application/octet-stream', originalname: 'p.exe' }, ['image'])).toBeNull();
  });
});

describe('uploadOptions', () => {
  it('sets a hard size ceiling equal to the largest allowed kind', () => {
    expect(uploadOptions('image').limits.fileSize).toBe(8 * MB);
    expect(uploadOptions('image', 'video').limits.fileSize).toBe(50 * MB);
    expect(uploadOptions('image', 'audio').limits.fileSize).toBe(8 * MB);
  });
  it('accepts a photo and rejects a text file with a friendly 400', async () => {
    const opts = uploadOptions('image');
    expect((await run(opts, { mimetype: 'image/jpeg', originalname: 'a.jpg' })).ok).toBe(true);
    const bad = await run(opts, { mimetype: 'text/plain', originalname: 'a.txt' });
    expect(bad.ok).toBe(false);
    expect(bad.err).toBeInstanceOf(BadRequestException);
    expect((bad.err as BadRequestException).message).toMatch(/JPG, PNG or WebP/);
  });
  it('repairs a generic MIME type so storage serves the file correctly', async () => {
    const file: any = { mimetype: 'application/octet-stream', originalname: 'photo.jpg' };
    await run(uploadOptions('image'), file);
    expect(file.mimetype).toBe('image/jpeg');
  });
});

describe('assertFileWithinLimit (per-kind size caps)', () => {
  it('allows an 8MB image and a 49MB video', () => {
    expect(assertFileWithinLimit({ mimetype: 'image/png', originalname: 'a.png', size: 8 * MB }, ['image', 'video'])).toBe('image');
    expect(assertFileWithinLimit({ mimetype: 'video/mp4', originalname: 'a.mp4', size: 49 * MB }, ['image', 'video'])).toBe('video');
  });
  it('rejects a 20MB image even though video would allow 50MB', () => {
    expect(() => assertFileWithinLimit({ mimetype: 'image/png', originalname: 'a.png', size: 20 * MB }, ['image', 'video'])).toThrow(PayloadTooLargeException);
  });
  it('rejects 6MB of audio (cap is 5MB) but allows a 6MB image in the same endpoint', () => {
    expect(() => assertFileWithinLimit({ mimetype: 'audio/mp4', originalname: 'v.m4a', size: 6 * MB }, ['image', 'audio'])).toThrow(PayloadTooLargeException);
    expect(assertFileWithinLimit({ mimetype: 'image/png', originalname: 'a.png', size: 6 * MB }, ['image', 'audio'])).toBe('image');
  });
  it('matches the agreed contract limits', () => {
    expect(UPLOAD_RULES.image.maxBytes).toBe(8 * MB);
    expect(UPLOAD_RULES.video.maxBytes).toBe(50 * MB);
    expect(UPLOAD_RULES.audio.maxBytes).toBe(5 * MB);
    expect(UPLOAD_RULES.document.maxBytes).toBe(10 * MB);
  });
});

describe('sanitizeFilename', () => {
  it('removes path traversal and odd characters but keeps the extension', () => {
    expect(sanitizeFilename('../../etc/passwd.pdf')).toBe('passwd.pdf');
    expect(sanitizeFilename('My Notes (final) #2.PDF')).toBe('My_Notes_final_2.pdf');
    expect(sanitizeFilename('..\\..\\evil.docx')).toBe('evil.docx');
  });
  it('handles empty, hidden and very long names', () => {
    expect(sanitizeFilename('')).toBe('file');
    expect(sanitizeFilename(undefined)).toBe('file');
    expect(sanitizeFilename('.hidden')).toBe('file.hidden'); // never a dotfile
    expect(sanitizeFilename('a'.repeat(300) + '.png').length).toBeLessThanOrEqual(64);
  });
});
