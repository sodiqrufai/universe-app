import { BadRequestException, PayloadTooLargeException } from '@nestjs/common';

const MB = 1024 * 1024;

export type UploadKind = 'image' | 'video' | 'audio' | 'document';

interface KindRule {
  maxBytes: number;
  mimes: string[];
  exts: string[];
  label: string;
}

/** Limits agreed in the shared contract (image 8MB, video 50MB, audio 5MB, doc 10MB). */
export const UPLOAD_RULES: Record<UploadKind, KindRule> = {
  image: {
    maxBytes: 8 * MB,
    mimes: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'],
    exts: ['jpg', 'jpeg', 'png', 'webp'],
    label: 'a JPG, PNG or WebP image',
  },
  video: {
    maxBytes: 50 * MB,
    mimes: ['video/mp4', 'video/quicktime', 'video/webm'],
    exts: ['mp4', 'mov', 'webm'],
    label: 'an MP4, MOV or WebM video',
  },
  audio: {
    maxBytes: 5 * MB,
    mimes: ['audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'audio/m4a', 'audio/aac', 'audio/webm', 'audio/ogg', 'audio/wav', 'audio/x-wav', 'video/webm', 'video/mp4'],
    exts: ['m4a', 'mp3', 'aac', 'webm', 'ogg', 'wav', 'mp4'],
    label: 'an audio recording',
  },
  document: {
    maxBytes: 10 * MB,
    mimes: [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/plain',
      'image/jpeg',
      'image/png',
    ],
    exts: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'jpg', 'jpeg', 'png'],
    label: 'a PDF, Word, PowerPoint, Excel, text or image file',
  },
};

const GENERIC_MIMES = new Set(['application/octet-stream', 'binary/octet-stream', '']);

const EXT_TO_MIME: Record<string, string> = {
  jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp',
  mp4: 'video/mp4', mov: 'video/quicktime', webm: 'video/webm',
  m4a: 'audio/mp4', mp3: 'audio/mpeg', aac: 'audio/aac', ogg: 'audio/ogg', wav: 'audio/wav',
  pdf: 'application/pdf', txt: 'text/plain',
  doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ppt: 'application/vnd.ms-powerpoint',
  pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  xls: 'application/vnd.ms-excel',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

function extOf(name?: string): string {
  const m = /\.([A-Za-z0-9]+)$/.exec(name ?? '');
  return m ? m[1].toLowerCase() : '';
}

function describe(kinds: UploadKind[]): string {
  return kinds.map((k) => UPLOAD_RULES[k].label).join(' or ');
}

/** Which of the allowed kinds does this file belong to? (null = none) */
export function classifyFile(file: { mimetype?: string; originalname?: string }, kinds: UploadKind[]): UploadKind | null {
  const mime = (file.mimetype ?? '').toLowerCase();
  const ext = extOf(file.originalname);
  for (const kind of kinds) {
    const rule = UPLOAD_RULES[kind];
    if (rule.mimes.includes(mime)) return kind;
  }
  // Some clients (notably Flutter web / image_picker) send a generic MIME type.
  // Fall back to the file extension rather than wrongly rejecting a real photo.
  if (GENERIC_MIMES.has(mime)) {
    for (const kind of kinds) {
      if (UPLOAD_RULES[kind].exts.includes(ext)) return kind;
    }
  }
  return null;
}

/**
 * Multer options for FileInterceptor / FilesInterceptor.
 *  - hard size ceiling = the largest allowed kind (memory-storage safety on Render)
 *  - rejects files whose type isn't allowed, with a friendly message
 *  - repairs a generic MIME type from the extension so storage serves it correctly
 */
export function uploadOptions(...kinds: UploadKind[]) {
  return {
    limits: {
      fileSize: Math.max(...kinds.map((k) => UPLOAD_RULES[k].maxBytes)),
      files: 6,
      fields: 30,
      parts: 40,
    },
    fileFilter: (_req: any, file: Express.Multer.File, cb: (error: Error | null, accept: boolean) => void) => {
      const kind = classifyFile(file, kinds);
      if (!kind) {
        return cb(new BadRequestException(`That file type isn't supported. Please upload ${describe(kinds)}.`), false);
      }
      if (GENERIC_MIMES.has((file.mimetype ?? '').toLowerCase())) {
        const fixed = EXT_TO_MIME[extOf(file.originalname)];
        if (fixed) file.mimetype = fixed;
      }
      cb(null, true);
    },
  };
}

/**
 * For endpoints that accept several kinds with different size caps
 * (stories: image 8MB / video 50MB; chat: image 8MB / audio 5MB).
 * Call after the interceptor has run. Returns the detected kind.
 */
export function assertFileWithinLimit(file: { mimetype?: string; originalname?: string; size?: number }, kinds: UploadKind[]): UploadKind {
  const kind = classifyFile(file, kinds);
  if (!kind) {
    throw new BadRequestException(`That file type isn't supported. Please upload ${describe(kinds)}.`);
  }
  const max = UPLOAD_RULES[kind].maxBytes;
  if ((file.size ?? 0) > max) {
    throw new PayloadTooLargeException(`That ${kind} is too large. The limit is ${Math.round(max / MB)}MB.`);
  }
  return kind;
}

/** Safe storage filename: no paths, no odd characters, bounded length, extension kept. */
export function sanitizeFilename(name?: string): string {
  const base = (name ?? 'file').split(/[\\/]/).pop() ?? 'file';
  const ext = extOf(base);
  const stem = base.replace(/\.[A-Za-z0-9]+$/, '').replace(/[^A-Za-z0-9._-]+/g, '_').replace(/_+/g, '_').replace(/^[._-]+/, '').slice(0, 60);
  return `${stem || 'file'}${ext ? '.' + ext : ''}`;
}
