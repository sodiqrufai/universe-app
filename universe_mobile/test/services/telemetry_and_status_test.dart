import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:universe_mobile/services/server_status.dart';
import 'package:universe_mobile/services/telemetry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Telemetry.resetForTesting);

  group('Telemetry', () {
    test('is a complete no-op without a key', () async {
      // Not enabled: track must not send anything and must not throw.
      Telemetry.track('post_created', {'x': 1});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(Telemetry.isEnabled, false);
    });

    test('sanitize drops sensitive names, nulls and non-primitive values', () {
      final out = Telemetry.sanitize({
        'token': 'abc',
        'password': 'x',
        'message_text': 'hello',
        'email': 'a@b.com',
        'matric_number': '123',
        'screen': 'LoginScreen',
        'count': 3,
        'ok': true,
        'nothing': null,
        'list': [1, 2],
      });
      expect(out, {'screen': 'LoginScreen', 'count': 3, 'ok': true});
    });

    test('sanitize shortens long strings', () {
      final out = Telemetry.sanitize({'screen': 'x' * 500});
      expect((out['screen'] as String).length, 100);
    });

    test('sends a capture request with a random id and no sensitive data', () async {
      http.Request? sent;
      Telemetry.enableForTesting(
        key: 'phc_test',
        client: MockClient((req) async {
          sent = req;
          return http.Response('{}', 200);
        }),
      );
      Telemetry.track('feedback_sent', {'category': 'bug', 'message': 'secret text'});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sent, isNotNull);
      expect(sent!.url.path, '/capture/');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect(body['event'], 'feedback_sent');
      expect(body['api_key'], 'phc_test');
      expect(body['distinct_id'], 'test-id');
      final props = body['properties'] as Map<String, dynamic>;
      expect(props['category'], 'bug');
      expect(props.containsKey('message'), false);
      expect(sent!.body.contains('secret text'), false);
    });

    test('a failing analytics server never throws into the app', () async {
      Telemetry.enableForTesting(
        key: 'phc_test',
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      Telemetry.track('post_created');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // Reaching here without an unhandled error is the assertion.
      expect(Telemetry.isEnabled, true);
    });
  });

  group('ServerStatus', () {
    test('tracks slow requests and notifies listeners', () {
      final s = ServerStatus();
      var notifications = 0;
      s.addListener(() => notifications++);

      final a = s.requestSlow();
      final b = s.requestSlow();
      expect(s.isWaking, true);
      s.requestFinished(a);
      expect(s.isWaking, true); // b is still slow
      s.requestFinished(b);
      expect(s.isWaking, false);
      expect(notifications, 4);
    });

    test('setOffline only notifies on a real change', () {
      final s = ServerStatus();
      var notifications = 0;
      s.addListener(() => notifications++);
      s.setOffline(false);
      s.setOffline(true);
      s.setOffline(true);
      s.markReachable();
      expect(s.isOffline, false);
      expect(notifications, 2);
    });
  });
}
