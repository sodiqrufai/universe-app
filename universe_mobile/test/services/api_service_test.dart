import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universe_mobile/config/api_config.dart';
import 'package:universe_mobile/services/api_service.dart';
import 'package:universe_mobile/services/resilient_client.dart';
import 'package:universe_mobile/services/server_status.dart';
import 'package:universe_mobile/services/session_service.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Runs [body] the way the real app does: inside a zone where `http.Client()`
/// is the ResilientClient wrapped around [handler].
Future<T> _withApi<T>(
  Future<http.Response> Function(http.Request) handler,
  Future<T> Function() body, {
  Duration timeout = const Duration(milliseconds: 200),
}) {
  return http.runWithClient(
    body,
    () => ResilientClient(
      inner: MockClient(handler),
      apiHost: Uri.parse(ApiConfig.baseUrl).host,
      status: ServerStatus(),
      timeout: timeout,
      retries: 2,
      backoff: const [Duration.zero],
      sleep: (_) async {},
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'tok',
      'refresh_token': 'ref',
      'user_id': 'u1',
    });
  });

  group('ApiService results', () {
    test('success keeps the body and adds statusCode', () async {
      String? auth;
      final r = await _withApi(
        (req) async {
          auth = req.headers['Authorization'];
          return _json({'success': true, 'profile': {'id': 'u1'}});
        },
        () => ApiService.get('/profile/me'),
      );
      expect(r['success'], true);
      expect(r['statusCode'], 200);
      expect(r['profile'], {'id': 'u1'});
      expect(auth, 'Bearer tok');
    });

    test('POST sends JSON', () async {
      String? contentType;
      Object? sent;
      final r = await _withApi(
        (req) async {
          contentType = req.headers['Content-Type'];
          sent = jsonDecode(req.body);
          return _json({'success': true});
        },
        () => ApiService.post('/feedback', {'message': 'hi'}),
      );
      expect(r['success'], true);
      expect(contentType, contains('application/json'));
      expect(sent, {'message': 'hi'});
    });

    test('empty 204 body counts as success', () async {
      final r = await _withApi(
        (_) async => http.Response('', 204),
        () => ApiService.delete('/x'),
      );
      expect(r['success'], true);
      expect(r['statusCode'], 204);
    });

    test('friendly backend error is passed through', () async {
      final r = await _withApi(
        (_) async => _json({'success': false, 'error': 'That username is taken.'}, 409),
        () => ApiService.post('/profile/username', {'username': 'a'}),
      );
      expect(r['success'], false);
      expect(r['error'], 'That username is taken.');
      expect(r['statusCode'], 409);
    });

    test('old NestJS shape: error comes from message, not "Bad Request"', () async {
      final r = await _withApi(
        (_) async => _json({
          'statusCode': 400,
          'message': ['username too short', 'username invalid'],
          'error': 'Bad Request',
        }, 400),
        () => ApiService.post('/x', {}),
      );
      expect(r['success'], false);
      expect(r['error'], 'username too short, username invalid');
    });

    test('403 is flagged restricted and keeps the real message', () async {
      final r = await _withApi(
        (_) async => _json({
          'statusCode': 403,
          'message': 'Your account is suspended.',
          'error': 'Forbidden',
        }, 403),
        () => ApiService.post('/posts', {}),
      );
      expect(r['restricted'], true);
      expect(r['error'], 'Your account is suspended.');
    });

    test('bare "Forbidden" with no message gets a human default', () async {
      final r = await _withApi(
        (_) async => _json({'statusCode': 403, 'error': 'Forbidden'}, 403),
        () => ApiService.get('/x'),
      );
      expect(r['error'], "You don't have permission to do that.");
    });

    test('429 sets rateLimited and a friendly message', () async {
      final r = await _withApi(
        (_) async => _json({
          'statusCode': 429,
          'message': 'ThrottlerException: Too Many Requests',
        }, 429),
        () => ApiService.post('/feedback', {}),
      );
      expect(r['success'], false);
      expect(r['rateLimited'], true);
      expect(r['statusCode'], 429);
      expect(r['error'], contains('Too many attempts'));
    });

    test('an HTML 502 page becomes a "waking up" message after retries', () async {
      var calls = 0;
      final r = await _withApi(
        (_) async {
          calls++;
          return http.Response('<html>Bad gateway</html>', 502);
        },
        () => ApiService.get('/x'),
      );
      expect(r['success'], false);
      expect(r['statusCode'], 502);
      expect(r['error'], contains('waking up'));
      expect(calls, 3); // GET: 1 try + 2 retries
    });

    test('a GET survives one dropped connection (retry)', () async {
      var calls = 0;
      final r = await _withApi(
        (_) async {
          calls++;
          if (calls == 1) throw http.ClientException('reset');
          return _json({'success': true});
        },
        () => ApiService.get('/x'),
      );
      expect(r['success'], true);
      expect(calls, 2);
    });

    test('offline/network failure: networkError, human error, no exception', () async {
      final r = await _withApi(
        (_) async => throw http.ClientException('no route'),
        () => ApiService.post('/x', {}),
      );
      expect(r['success'], false);
      expect(r['networkError'], true);
      expect(r['error'], isA<String>());
      expect((r['error'] as String).isNotEmpty, true);
      expect(r.containsKey('statusCode'), false);
    });

    test('timeout: timedOut + networkError flags, human error', () async {
      final never = Completer<http.Response>();
      final r = await _withApi(
        (_) => never.future,
        () => ApiService.post('/x', {}),
        timeout: const Duration(milliseconds: 50),
      );
      expect(r['success'], false);
      expect(r['timedOut'], true);
      expect(r['networkError'], true);
      expect(r['error'], contains('taking too long'));
    });

    test('non-JSON 200 body is reported, not thrown', () async {
      final r = await _withApi(
        (_) async => http.Response('hello', 200),
        () => ApiService.get('/x'),
      );
      expect(r['success'], false);
      expect(r['error'], isA<String>());
    });
  });

  group('ApiService token refresh', () {
    test('401 -> refresh -> retries the call with the new token', () async {
      final seenAuth = <String?>[];
      final r = await _withApi(
        (req) async {
          if (req.url.path == '/auth/refresh') {
            return _json({'success': true, 'accessToken': 'new', 'refreshToken': 'r2'});
          }
          seenAuth.add(req.headers['Authorization']);
          return req.headers['Authorization'] == 'Bearer new'
              ? _json({'success': true})
              : _json({'statusCode': 401, 'message': 'Unauthorized'}, 401);
        },
        () => ApiService.get('/profile/me'),
      );
      expect(r['success'], true);
      expect(seenAuth, ['Bearer tok', 'Bearer new']);
      expect(await SessionService.getToken(), 'new');
      expect(await SessionService.getRefreshToken(), 'r2');
    });

    test('401 and refresh fails -> clear human error with statusCode 401', () async {
      final r = await _withApi(
        (req) async {
          if (req.url.path == '/auth/refresh') {
            return _json({'success': false, 'error': 'expired'}, 401);
          }
          return _json({'statusCode': 401, 'message': 'Unauthorized'}, 401);
        },
        () => ApiService.get('/profile/me'),
      );
      expect(r['success'], false);
      expect(r['statusCode'], 401);
      expect(r['error'], 'Please sign in again.');
    });

    test('two parallel 401s trigger only ONE refresh', () async {
      var refreshes = 0;
      final results = await _withApi(
        (req) async {
          if (req.url.path == '/auth/refresh') {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return _json({'success': true, 'accessToken': 'new', 'refreshToken': 'r2'});
          }
          return req.headers['Authorization'] == 'Bearer new'
              ? _json({'success': true})
              : _json({'statusCode': 401, 'message': 'Unauthorized'}, 401);
        },
        () => Future.wait([ApiService.get('/a'), ApiService.get('/b')]),
      );
      expect(results.every((r) => r['success'] == true), true);
      expect(refreshes, 1);
    });
  });
}
