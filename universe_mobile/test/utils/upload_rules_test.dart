import 'package:flutter_test/flutter_test.dart';
import 'package:universe_mobile/utils/upload_rules.dart';

const mb = 1024 * 1024;

void main() {
  group('limits match the backend contract', () {
    test('image 8MB, video 50MB, audio 5MB, document 10MB', () {
      expect(UploadRules.rules[UploadKind.image]!.maxBytes, 8 * mb);
      expect(UploadRules.rules[UploadKind.video]!.maxBytes, 50 * mb);
      expect(UploadRules.rules[UploadKind.audio]!.maxBytes, 5 * mb);
      expect(UploadRules.rules[UploadKind.document]!.maxBytes, 10 * mb);
    });

    test('allowed extensions', () {
      expect(UploadRules.rules[UploadKind.image]!.extensions,
          ['jpg', 'jpeg', 'png', 'webp']);
      expect(UploadRules.rules[UploadKind.video]!.extensions,
          ['mp4', 'mov', 'webm']);
      expect(UploadRules.rules[UploadKind.document]!.extensions,
          containsAll(['pdf', 'docx', 'pptx', 'png', 'jpg']));
    });
  });

  group('extensionOf / resolvedName', () {
    test('lower-cases and handles missing extensions', () {
      expect(UploadRules.extensionOf('Photo.JPG'), 'jpg');
      expect(UploadRules.extensionOf('archive.tar.gz'), 'gz');
      expect(UploadRules.extensionOf('noext'), '');
      expect(UploadRules.extensionOf('trailing.'), '');
    });

    test('adds an extension from the MIME type when the name has none', () {
      expect(UploadRules.resolvedName('image_123', 'image/png'), 'image_123.png');
      expect(UploadRules.resolvedName('clip', 'video/mp4'), 'clip.mp4');
      expect(UploadRules.resolvedName('photo.jpg', 'image/png'), 'photo.jpg');
      expect(UploadRules.resolvedName('', 'image/jpeg'), 'upload.jpg');
      expect(UploadRules.resolvedName('blob', null), 'blob');
    });
  });

  group('formatMb', () {
    test('rounds up to one decimal and drops a trailing .0', () {
      expect(UploadRules.formatMb(63 * mb), '63');
      expect(UploadRules.formatMb(8 * mb + 1), '8.1');
      expect(UploadRules.formatMb((9.2 * mb).round()), '9.2');
      expect(UploadRules.formatMb(1), '0.1');
    });
  });

  group('validate', () {
    test('accepts a normal image', () {
      expect(UploadRules.validate(fileName: 'a.jpg', sizeBytes: 2 * mb), isNull);
      expect(UploadRules.validate(fileName: 'A.PNG', sizeBytes: 100), isNull);
      expect(UploadRules.validate(fileName: 'x.webp', sizeBytes: 1), isNull);
    });

    test('exactly at the limit passes, one byte over fails', () {
      expect(UploadRules.validate(fileName: 'a.jpg', sizeBytes: 8 * mb), isNull);
      expect(
        UploadRules.validate(fileName: 'a.jpg', sizeBytes: 8 * mb + 1),
        'That image is 8.1MB. The limit is 8MB.',
      );
    });

    test('video message names the size and limit', () {
      expect(
        UploadRules.validate(
          fileName: 'party.mp4',
          sizeBytes: 63 * mb,
          allowed: const [UploadKind.video],
        ),
        'That video is 63MB. The limit is 50MB.',
      );
      expect(
        UploadRules.validate(
          fileName: 'party.mov',
          sizeBytes: 50 * mb,
          allowed: const [UploadKind.video],
        ),
        isNull,
      );
    });

    test('audio limit is 5MB', () {
      expect(
        UploadRules.validate(
          fileName: 'v.m4a',
          sizeBytes: 6 * mb,
          allowed: const [UploadKind.audio],
        ),
        'That voice note is 6MB. The limit is 5MB.',
      );
    });

    test('document limit is 10MB and the noun is "file"', () {
      expect(
        UploadRules.validate(
          fileName: 'notes.pdf',
          sizeBytes: 14 * mb,
          allowed: const [UploadKind.document],
        ),
        'That file is 14MB. The limit is 10MB.',
      );
      expect(
        UploadRules.validate(
          fileName: 'slides.pptx',
          sizeBytes: 9 * mb,
          allowed: const [UploadKind.document],
        ),
        isNull,
      );
    });

    test('rejects the wrong type with the backend wording', () {
      expect(
        UploadRules.validate(fileName: 'a.gif', sizeBytes: mb),
        "That file type isn't supported. Please upload a JPG, PNG or WebP image.",
      );
      expect(
        UploadRules.validate(
          fileName: 'a.exe',
          sizeBytes: mb,
          allowed: const [UploadKind.document],
        ),
        "That file type isn't supported. Please upload "
        'a PDF, Word, PowerPoint, Excel, text or image file.',
      );
    });

    test('a video is not accepted where only images are allowed', () {
      expect(UploadRules.validate(fileName: 'a.mp4', sizeBytes: mb), isNotNull);
    });

    test('several allowed kinds use each kind\'s own limit', () {
      const both = [UploadKind.image, UploadKind.video];
      expect(UploadRules.validate(fileName: 'a.jpg', sizeBytes: 9 * mb, allowed: both),
          'That image is 9MB. The limit is 8MB.');
      expect(UploadRules.validate(fileName: 'a.mp4', sizeBytes: 40 * mb, allowed: both),
          isNull);
      expect(
        UploadRules.validate(fileName: 'a.gif', sizeBytes: mb, allowed: both),
        "That file type isn't supported. Please upload "
        'a JPG, PNG or WebP image or an MP4, MOV or WebM video.',
      );
    });

    test('empty files are rejected', () {
      expect(
        UploadRules.validate(fileName: 'a.jpg', sizeBytes: 0),
        'That file is empty. Please choose a different one.',
      );
    });

    test('HEIC gets a helpful message', () {
      final msg = UploadRules.validate(fileName: 'IMG_1.HEIC', sizeBytes: mb);
      expect(msg, contains('HEIC'));
    });

    test('a nameless web file is accepted when the MIME type is known', () {
      expect(
        UploadRules.validate(fileName: 'blob', sizeBytes: mb, mimeType: 'image/jpeg'),
        isNull,
      );
      expect(UploadRules.validate(fileName: 'blob', sizeBytes: mb), isNotNull);
    });
  });

  group('classify', () {
    test('picks the right kind from the extension', () {
      const all = UploadKind.values;
      expect(UploadRules.classify('a.webp', all), UploadKind.image);
      expect(UploadRules.classify('a.mov', all), UploadKind.video);
      expect(UploadRules.classify('a.ogg', all), UploadKind.audio);
      expect(UploadRules.classify('a.docx', all), UploadKind.document);
      expect(UploadRules.classify('a.zip', all), isNull);
    });
  });
}
