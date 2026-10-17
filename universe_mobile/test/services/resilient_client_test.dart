import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:universe_mobile/services/resilient_client.dart';
import 'package:universe_mobile/services/server_status.dart';

const _host = 'api.test';
Uri _api(String path) => Uri.https(_host, path);

http.Response _ok([String body = '{"success":true}']) => http.Response(body, 200);

ResilientClient _client(
  http.Client inner, {
  ServerStatus? status,
  bool offline = false,
  int retries = 2,
  Duration timeout = const Duration(milliseconds: 200),
  Duration slowAfter = const Duration(seconds: 5),
}) {
  return ResilientClient(
    inner: inner,
    apiHost: _host,
    status: status ?? ServerStatus(),
    timeout: timeout,
    uploadTimeout: timeout,
    slowAfter: slowAfter,
    retries: retries,
    backoff: const [Duration.zero],
    sleep: (_) async {},
    isOffline: () => offline,
  );
}

class _FlagClient extends http.BaseClient {
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(Stream.value(const <int>[]), 200);
  @override
  void close() => closed = true;
}

void main() {
  group('ResilientClient', () {
    test('passes a normal successful GET straight through', () async {
      var calls = 0;
      final c = _client(MockClient((_) async {
        calls++;
        return _ok();
      }));
      final res = await c.get(_api('/x'));
      expect(res.statusCode, 200);
      expect(calls, 1);
    });

    test('retries a GET after a network failure and then succeeds', () async {
      var calls = 0;
      final c = _client(MockClient((_) async {
        calls++;
        if (calls == 1) throw http.ClientException('connection reset');
        return _ok();
      }));
      final res = await c.get(_api('/x'));
      expect(res.statusCode, 200);
      expect(calls, 2);
    });

    test('retries a GET on 503 (server waking) and then succeeds', () async {
      var calls = 0;
      final c = _client(MockClient((_) async {
        calls++;
        return calls < 3 ? http.Response('<html>wake</html>', 503) : _ok();
      }));
      final res = await c.get(_api('/x'));
      expect(res.statusCode, 200);
      expect(calls, 3);
    });

    test('returns the last 503 once retries are used up', () async {
      var calls = 0;
      final c = _client(MockClient((_) async {
        calls++;
        return http.Response('down', 503);
      }));
      final res = await c.get(_api('/x'));
      expect(res.statusCode, 503);
      expect(calls, 3); // 1 try + 2 retries
    });

    test('gives a friendly ResilientHttpException after repeated failures', () async {
      var calls = 0;
      final c = _client(MockClient((_) async {
        calls++;
        throw http.ClientException('socket closed');
      }));
      await expectLater(
        c.get(_api('/x')),
        throwsA(isA<ResilientHttpException>()
            .having((e) => e.timedOut, 'timedOut', false)
            .having((e) => e.offline, 'offline', false)
            .having((e) => e.toString(), 'message', contains("Couldn't reach"))),
      );
      expect(calls, 3);
    });

    test('times out a request that never answers', () async {
      final never = Completer<http.Response>();
      final c = _client(
        MockClient((_) => never.future),
        retries: 0,
        timeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        c.get(_api('/x')),
        throwsA(isA<ResilientHttpException>().having((e) => e.timedOut, 'timedOut', true)),
      );
    });

    test('does NOT retry a POST (it might have been applied)', () async {
      var calls = 0;
      final c = _client(MockClient((_) async {
        calls++;
        throw http.ClientException('dropped');
      }));
      await expectLater(
        c.post(_api('/x'), body: 'a=b'),
        throwsA(isA<ResilientHttpException>()),
      );
      expect(calls, 1);
    });

    test('does NOT retry on HTTP 429 and hands it back untouched', () async {
      var calls = 0;
      final c = _client(MockClient((_) async {
        calls++;
        return http.Response('{"statusCode":429}', 429);
      }));
      final res = await c.get(_api('/x'));
      expect(res.statusCode, 429);
      expect(calls, 1);
    });

    test('reports offline, without retrying, when the device is offline', () async {
      var calls = 0;
      final c = _client(
        MockClient((_) async {
          calls++;
          throw http.ClientException('no network');
        }),
        offline: true,
      );
      await expectLater(
        c.get(_api('/x')),
        throwsA(isA<ResilientHttpException>()
            .having((e) => e.offline, 'offline', true)
            .having((e) => e.toString(), 'message', contains('offline'))),
      );
      expect(calls, 1);
    });

    test('keeps headers and body when it retries', () async {
      final seen = <http.Request>[];
      final c = _client(MockClient((req) async {
        seen.add(req);
        if (seen.length == 1) throw http.ClientException('x');
        return _ok();
      }));
      await c.get(_api('/x'), headers: {'Authorization': 'Bearer abc'});
      expect(seen, hasLength(2));
      expect(seen[1].headers['Authorization'], 'Bearer abc');
      expect(seen[1].url, _api('/x'));
    });

    test('leaves other hosts alone (no retries, no wrapping)', () async {
      var calls = 0;
      final c = _client(MockClient((_) async {
        calls++;
        throw http.ClientException('image host down');
      }));
      await expectLater(
        c.get(Uri.https('images.example.com', '/a.png')),
        throwsA(isA<http.ClientException>()
            .having((e) => e is ResilientHttpException, 'is resilient', false)),
      );
      expect(calls, 1);
    });

    test('multipart uploads go through the app-wide client zone', () async {
      var sawUpload = false;
      final status = ServerStatus();
      await http.runWithClient(() async {
        final req = http.MultipartRequest('POST', _api('/upload'))
          ..fields['title'] = 'hello';
        final streamed = await req.send();
        expect(streamed.statusCode, 200);
      }, () => _client(MockClient((req) async {
            sawUpload = req.url.path == '/upload' && req.method == 'POST';
            return _ok();
          }), status: status));
      expect(sawUpload, true);
    });

    test('top-level http.get is routed through the zone client and retried', () async {
      var calls = 0;
      await http.runWithClient(() async {
        final res = await http.get(_api('/x'));
        expect(res.statusCode, 200);
      }, () => _client(MockClient((_) async {
            calls++;
            if (calls == 1) throw http.ClientException('blip');
            return _ok();
          })));
      expect(calls, 2);
    });

    test('shows "slow" in ServerStatus while a request is taking long', () async {
      final status = ServerStatus();
      final gate = Completer<http.Response>();
      final c = _client(
        MockClient((_) => gate.future),
        status: status,
        slowAfter: const Duration(milliseconds: 20),
        timeout: const Duration(seconds: 2),
      );
      final pending = c.get(_api('/x'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(status.isWaking, true);
      gate.complete(_ok());
      await pending;
      expect(status.isWaking, false);
    });

    test('a quick request never flips the slow flag', () async {
      final status = ServerStatus();
      var everSlow = false;
      status.addListener(() => everSlow = everSlow || status.isWaking);
      final c = _client(MockClient((_) async => _ok()), status: status);
      await c.get(_api('/x'));
      expect(everSlow, false);
    });

    test('any response from our server clears the offline flag', () async {
      final status = ServerStatus()..setOffline(true);
      final c = _client(MockClient((_) async => _ok()), status: status);
      await c.get(_api('/x'));
      expect(status.isOffline, false);
    });

    test('close() does not close the shared inner client', () {
      final inner = _FlagClient();
      _client(inner).close();
      expect(inner.closed, false);
    });
  });
}
