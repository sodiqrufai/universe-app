import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/resilient_client.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

/// The kinds of file the backend accepts. Mirrors
/// `universe_backend/src/common/upload.ts`; if you change a limit there,
/// change it here too (and in test/utils/upload_rules_test.dart).
enum UploadKind { image, video, audio, document }

class UploadRule {
  const UploadRule({
    required this.maxBytes,
    required this.extensions,
    required this.noun,
    required this.accepts,
  });

  final int maxBytes;
  final List<String> extensions;

  /// How we name this kind in a sentence: "That video is 63MB."
  final String noun;

  /// Completes "Please upload ...": "a JPG, PNG or WebP image".
  final String accepts;

  int get maxMb => maxBytes ~/ UploadRules.mb;
}

/// Single source of truth for upload limits on the app side.
///
/// Everything is decided from the file name's extension and the size in
/// bytes, so it works the same on Android, iOS and Flutter web (no dart:io).
class UploadRules {
  UploadRules._();

  static const int mb = 1024 * 1024;

  /// Marketplace / services listings accept up to this many photos.
  static const int maxListingImages = 6;

  static const Map<UploadKind, UploadRule> rules = {
    UploadKind.image: UploadRule(
      maxBytes: 8 * mb,
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
      noun: 'image',
      accepts: 'a JPG, PNG or WebP image',
    ),
    UploadKind.video: UploadRule(
      maxBytes: 50 * mb,
      extensions: ['mp4', 'mov', 'webm'],
      noun: 'video',
      accepts: 'an MP4, MOV or WebM video',
    ),
    UploadKind.audio: UploadRule(
      maxBytes: 5 * mb,
      extensions: ['m4a', 'mp3', 'aac', 'webm', 'ogg', 'wav', 'mp4'],
      noun: 'voice note',
      accepts: 'an audio recording',
    ),
    UploadKind.document: UploadRule(
      maxBytes: 10 * mb,
      extensions: [
        'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', //
        'jpg', 'jpeg', 'png',
      ],
      noun: 'file',
      accepts: 'a PDF, Word, PowerPoint, Excel, text or image file',
    ),
  };

  static const Map<String, String> _mimeToExtension = {
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'video/webm': 'webm',
    'audio/webm': 'webm',
    'audio/ogg': 'ogg',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'audio/mpeg': 'mp3',
    'audio/aac': 'aac',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'application/pdf': 'pdf',
    'text/plain': 'txt',
  };

  /// Lower-case extension without the dot, or '' if there isn't one.
  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).trim().toLowerCase();
  }

  /// A file name that always carries an extension the backend recognises.
  /// Flutter web sometimes hands back names with no extension; the backend
  /// decides the type from the extension, so add one from the MIME type.
  static String resolvedName(String fileName, [String? mimeType]) {
    final base = fileName.trim().isEmpty ? 'upload' : fileName.trim();
    if (extensionOf(base).isNotEmpty) return base;
    final ext = _mimeToExtension[(mimeType ?? '').toLowerCase()];
    return ext == null ? base : '$base.$ext';
  }

  /// Which of [allowed] this file name belongs to, or null if none.
  static UploadKind? classify(String fileName, List<UploadKind> allowed) {
    final ext = extensionOf(fileName);
    if (ext.isEmpty) return null;
    for (final kind in allowed) {
      if (rules[kind]!.extensions.contains(ext)) return kind;
    }
    return null;
  }

  /// "63" or "8.3": size in MB, rounded UP to one decimal so a file that is
  /// over the limit never displays as exactly the limit.
  static String formatMb(int bytes) {
    final tenths = (bytes * 10 + mb - 1) ~/ mb;
    final whole = tenths ~/ 10;
    final frac = tenths % 10;
    return frac == 0 ? '$whole' : '$whole.$frac';
  }

  /// "That file type isn't supported. Please upload a JPG, PNG or WebP image."
  static String unsupportedMessage(List<UploadKind> allowed) {
    final parts = allowed.map((k) => rules[k]!.accepts).toList();
    return "That file type isn't supported. Please upload ${parts.join(' or ')}.";
  }

  /// Returns a friendly error message, or null if the file is fine to upload.
  /// Checks type (by extension) AND size, against the same limits the
  /// backend enforces.
  static String? validate({
    required String fileName,
    required int sizeBytes,
    List<UploadKind> allowed = const [UploadKind.image],
    String? mimeType,
  }) {
    final name = resolvedName(fileName, mimeType);
    final kind = classify(name, allowed);
    if (kind == null) {
      final ext = extensionOf(name);
      if ((ext == 'heic' || ext == 'heif') && allowed.contains(UploadKind.image)) {
        return "HEIC photos aren't supported yet. Please choose a JPG or PNG "
            "photo (on iPhone: Settings > Camera > Formats > Most Compatible).";
      }
      return unsupportedMessage(allowed);
    }
    if (sizeBytes <= 0) {
      return 'That file is empty. Please choose a different one.';
    }
    final rule = rules[kind]!;
    if (sizeBytes > rule.maxBytes) {
      return 'That ${rule.noun} is ${formatMb(sizeBytes)}MB. '
          'The limit is ${rule.maxMb}MB.';
    }
    return null;
  }
}

// -----------------------------------------------------------------------------
// Picking files (web-safe: everything is read as bytes, never dart:io paths)
// -----------------------------------------------------------------------------

/// A file the user picked, already validated and held in memory.
class PickedUpload {
  const PickedUpload({required this.bytes, required this.name, this.mimeType});

  final Uint8List bytes;
  final String name;
  final String? mimeType;

  int get size => bytes.length;
}

class PickResult {
  const PickResult({this.file, this.error});

  final PickedUpload? file;

  /// A friendly message when the pick failed or the file was rejected.
  final String? error;

  /// The user closed the picker without choosing anything.
  bool get cancelled => file == null && error == null;
}

class MultiPickResult {
  const MultiPickResult({this.files = const [], this.error});

  final List<PickedUpload> files;
  final String? error;
}

class UploadPicker {
  UploadPicker._();

  static const String _openFailed =
      "Couldn't open your photos. Please check that UniVerse is allowed to "
      'access them and try again.';

  static Future<PickResult> pickImage({int quality = 80}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: quality,
      );
      if (picked == null) return const PickResult();
      return await fromXFile(picked, const [UploadKind.image]);
    } catch (_) {
      return const PickResult(error: _openFailed);
    }
  }

  /// Picks several photos, keeping at most [remaining]. Files that fail
  /// validation are skipped and the first problem is reported in `error`.
  static Future<MultiPickResult> pickImages({
    required int remaining,
    int quality = 80,
  }) async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: quality);
      if (picked.isEmpty) return const MultiPickResult();
      final files = <PickedUpload>[];
      String? error;
      for (final x in picked.take(remaining)) {
        final r = await fromXFile(x, const [UploadKind.image]);
        if (r.file != null) {
          files.add(r.file!);
        } else {
          error ??= r.error;
        }
      }
      if (error == null && picked.length > remaining) {
        error = 'You can add up to ${UploadRules.maxListingImages} photos. '
            'The extra ones were skipped.';
      }
      return MultiPickResult(files: files, error: error);
    } catch (_) {
      return const MultiPickResult(error: _openFailed);
    }
  }

  static Future<PickResult> pickVideo({Duration? maxDuration}) async {
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxDuration,
      );
      if (picked == null) return const PickResult();
      return await fromXFile(picked, const [UploadKind.video]);
    } catch (_) {
      return const PickResult(
        error: "Couldn't open your videos. Please check that UniVerse is "
            'allowed to access them and try again.',
      );
    }
  }

  /// Validates an [XFile] (size first, so we never load a huge file into
  /// memory just to reject it) and reads it as bytes.
  static Future<PickResult> fromXFile(XFile x, List<UploadKind> allowed) async {
    try {
      final size = await x.length();
      final problem = UploadRules.validate(
        fileName: x.name,
        sizeBytes: size,
        allowed: allowed,
        mimeType: x.mimeType,
      );
      if (problem != null) return PickResult(error: problem);
      final bytes = await x.readAsBytes();
      return PickResult(
        file: PickedUpload(
          bytes: bytes,
          name: UploadRules.resolvedName(x.name, x.mimeType),
          mimeType: x.mimeType,
        ),
      );
    } catch (_) {
      return const PickResult(
        error: "Couldn't read that file. Please try another one.",
      );
    }
  }
}

// -----------------------------------------------------------------------------
// Sending files
// -----------------------------------------------------------------------------

class UploadFile {
  const UploadFile({required this.field, required this.bytes, required this.name});

  /// The multipart field name the backend expects (`file`, `images`, ...).
  final String field;
  final Uint8List bytes;
  final String name;
}

/// Multipart upload with the same result shape as [ApiService]:
/// `success`, `error` (friendly, when not successful), `statusCode`,
/// `networkError`, `timedOut`, `rateLimited`, `restricted`.
///
/// It never throws. Callers check `result['success'] == true`.
/// Progress is indeterminate (the http package cannot report upload
/// progress), so screens show a spinner and disable the button.
class UploadApi {
  UploadApi._();

  static Future<Map<String, dynamic>> send(
    String path, {
    Map<String, String> fields = const {},
    List<UploadFile> files = const [],
  }) async {
    var result = await _once(path, fields, files);
    if (result['statusCode'] == 401) {
      // Expired token. ApiService refreshes it (once, safely) when one of its
      // own calls gets a 401, so make a cheap call and then resend. A
      // MultipartRequest can't be re-sent, so it is rebuilt.
      final probe = await ApiService.get('/profile/me');
      if (probe['success'] == true) {
        result = await _once(path, fields, files);
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> _once(
    String path,
    Map<String, String> fields,
    List<UploadFile> files,
  ) async {
    try {
      final token = await SessionService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$path'),
      );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields.addAll(fields);
      for (final f in files) {
        request.files.add(
          http.MultipartFile.fromBytes(f.field, f.bytes, filename: f.name),
        );
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } on TimeoutException catch (_) {
      return _fail(
        'The upload took too long. Check your connection and try again.',
        timedOut: true,
      );
    } on ResilientHttpException catch (e) {
      return _fail(e.message, networkError: !e.timedOut, timedOut: e.timedOut);
    } on http.ClientException catch (_) {
      return _fail(
        "Couldn't reach the server. Check your connection and try again.",
        networkError: true,
      );
    } catch (_) {
      return _fail('Something went wrong with the upload. Please try again.');
    }
  }

  static Map<String, dynamic> _fail(
    String error, {
    int? statusCode,
    bool networkError = false,
    bool timedOut = false,
    bool rateLimited = false,
  }) {
    return {
      'success': false,
      'error': error,
      if (statusCode != null) 'statusCode': statusCode,
      if (networkError) 'networkError': true,
      if (timedOut) 'timedOut': true,
      if (rateLimited) 'rateLimited': true,
    };
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final status = response.statusCode;
    final body = response.body.trim();

    dynamic decoded;
    if (body.isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        decoded = null;
      }
    }

    if (decoded is Map<String, dynamic>) {
      final result = Map<String, dynamic>.from(decoded);
      result['statusCode'] = status;
      if (status >= 400 || result['success'] == false) {
        result['success'] = false;
        result['error'] = _pickError(result, status);
        if (status == 429) result['rateLimited'] = true;
        if (status == 403) result['restricted'] = true;
      }
      return result;
    }

    // Not JSON: typically an HTML error page from a proxy (e.g. a 413 from the
    // host when a file is too large, or a 502 while the server wakes up).
    if (status >= 200 && status < 300) {
      return _fail(
        'Unexpected response from the server. Please try again.',
        statusCode: status,
      );
    }
    return _fail(
      _defaultErrorFor(status),
      statusCode: status,
      rateLimited: status == 429,
    );
  }

  static const Set<String> _statusNames = {
    'Bad Request',
    'Unauthorized',
    'Forbidden',
    'Not Found',
    'Payload Too Large',
    'Request Entity Too Large',
    'Unprocessable Entity',
    'Too Many Requests',
    'Internal Server Error',
    'Bad Gateway',
    'Service Unavailable',
    'Gateway Timeout',
  };

  static String? _usable(dynamic value) {
    if (value is List) value = value.map((e) => e.toString()).join(', ');
    if (value is! String) return null;
    final s = value.trim();
    if (s.isEmpty || _statusNames.contains(s)) return null;
    return s;
  }

  static String _pickError(Map<String, dynamic> data, int status) {
    return _usable(data['error']) ??
        _usable(data['message']) ??
        _defaultErrorFor(status);
  }

  static String _defaultErrorFor(int status) {
    if (status == 413) {
      return 'That file is too large to upload. Please choose a smaller one.';
    }
    if (status == 429) {
      return "You're doing that too fast. Please wait a moment and try again.";
    }
    if (status == 401) return 'Your session has expired. Please log in again.';
    if (status == 403) return "Your account can't do that right now.";
    if (status >= 500) {
      return 'The server had a problem. Please try again in a moment.';
    }
    return 'The upload failed. Please try again.';
  }
}

/// Inline error with an optional "Try again" button, used under upload forms.
class UploadErrorBox extends StatelessWidget {
  const UploadErrorBox({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: AppColors.error)),
          if (onRetry != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }
}
