import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/api_exception.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/session/session_store.dart';

import '../../../testing/fake_http_client_adapter.dart';

const _refreshPath = '/v1/auth/refresh';

const _expired = Session(accessToken: 'access-1', refreshToken: 'refresh-1');
const _renewed = Session(accessToken: 'access-2', refreshToken: 'refresh-2');

ResponseBody _tokens(Session session) => jsonResponse(200, {
  'accessToken': session.accessToken,
  'refreshToken': session.refreshToken,
  'user': {
    'id': '0190e0d4-0000-7000-8000-000000000001',
    'name': 'Marina Souza',
    'email': 'marina@email.com',
    'phone': null,
    'donationLocation': null,
  },
});

void main() {
  late FakeHttpClientAdapter adapter;
  late SessionStore sessionStore;
  late ApiClient client;

  /// Answers `/v1/me` with `401 UNAUTHENTICATED` unless it carries
  /// [_renewed]'s token, and the refresh with [refresh].
  void serve({required Future<ResponseBody> Function() refresh}) {
    adapter.respond = (options) async {
      if (options.path == _refreshPath) return refresh();
      final authorization = options.headers['Authorization'];
      if (authorization == 'Bearer ${_renewed.accessToken}') {
        return jsonResponse(200, {'name': 'Marina'});
      }
      return problemResponse(401, ApiErrorCode.unauthenticated);
    };
  }

  List<RequestOptions> refreshes() =>
      adapter.requests.where((r) => r.path == _refreshPath).toList();

  List<RequestOptions> calls(String path) =>
      adapter.requests.where((r) => r.path == path).toList();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = FakeHttpClientAdapter((_) async => jsonResponse(200, {}));
    sessionStore = await SessionStore.load();
    await sessionStore.save(_expired);
    client = ApiClient(
      baseUrl: 'http://api.test',
      appVersion: '0.1.0',
      updateRequired: UpdateRequired(),
      sessionStore: sessionStore,
      httpClientAdapter: adapter,
    );
  });

  test(
    'a 401 renews the session once, saves the new tokens and repeats the call',
    () async {
      serve(refresh: () async => _tokens(_renewed));

      final name = await client.get('/v1/me', (json) => json['name']);

      expect(name, 'Marina');
      expect(sessionStore.session, _renewed);
      final refresh = refreshes().single;
      expect(jsonDecode(jsonEncode(refresh.data)), {
        'refreshToken': _expired.refreshToken,
      });
      expect(refresh.headers['X-App-Version'], '0.1.0');
      final me = calls('/v1/me');
      expect(me, hasLength(2));
      expect(me.last.headers['Authorization'], 'Bearer access-2');
    },
  );

  test('three 401s at the same time share one refresh', () async {
    final refreshAnswer = Completer<ResponseBody>();
    serve(refresh: () => refreshAnswer.future);

    final names = Future.wait([
      for (var i = 0; i < 3; i++) client.get('/v1/me', (json) => json['name']),
    ]);
    // Let all three get their 401 before the refresh answers.
    await pumpEventQueue();
    refreshAnswer.complete(_tokens(_renewed));

    expect(await names, ['Marina', 'Marina', 'Marina']);
    expect(refreshes(), hasLength(1));
    expect(calls('/v1/me'), hasLength(6));
  });

  test('a 401 after another call already renewed only repeats', () async {
    serve(refresh: () async => _tokens(_renewed));
    final answer = adapter.respond;
    // The call goes out with the old token; the session is renewed elsewhere
    // before its 401 comes back.
    adapter.respond = (options) async {
      if (options.path == '/v1/me' && sessionStore.session == _expired) {
        await sessionStore.save(_renewed);
      }
      return answer(options);
    };

    final name = await client.get('/v1/me', (json) => json['name']);

    expect(name, 'Marina');
    expect(refreshes(), isEmpty);
    expect(calls('/v1/me'), hasLength(2));
  });

  test('a refused refresh clears the session', () async {
    serve(
      refresh: () async => problemResponse(401, ApiErrorCode.unauthenticated),
    );
    var notified = 0;
    sessionStore.addListener(() => notified++);

    await expectLater(
      client.get('/v1/me', (json) => json),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.code, 'code', ApiErrorCode.unauthenticated),
      ),
    );
    expect(sessionStore.session, isNull);
    expect(notified, 1);
    expect(calls('/v1/me'), hasLength(1));
  });

  test('a network failure on the refresh keeps the session', () async {
    serve(
      refresh: () async => throw DioException.connectionError(
        requestOptions: RequestOptions(path: _refreshPath),
        reason: 'offline',
      ),
    );

    await expectLater(
      client.get('/v1/me', (json) => json),
      throwsA(isA<ApiConnectionException>()),
    );
    expect(sessionStore.session, _expired);
  });

  test('another error on the refresh keeps the session', () async {
    serve(refresh: () async => problemResponse(500, 'INTERNAL_ERROR'));

    await expectLater(
      client.get('/v1/me', (json) => json),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 500)),
    );
    expect(sessionStore.session, _expired);
  });

  test('repeats each call only once', () async {
    // The API keeps refusing even the renewed token.
    adapter.respond = (options) async {
      if (options.path == _refreshPath) return _tokens(_renewed);
      return problemResponse(401, ApiErrorCode.unauthenticated);
    };

    await expectLater(
      client.get('/v1/me', (json) => json),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.unauthenticated,
        ),
      ),
    );
    expect(calls('/v1/me'), hasLength(2));
    expect(refreshes(), hasLength(1));
  });

  test('without a session a 401 is not refreshed', () async {
    await sessionStore.clear();
    serve(refresh: () async => _tokens(_renewed));

    await expectLater(
      client.get('/v1/me', (json) => json),
      throwsA(isA<ApiException>()),
    );
    expect(refreshes(), isEmpty);
  });

  test('a 401 with another code is not refreshed', () async {
    adapter.respond = (options) async {
      if (options.path == _refreshPath) return _tokens(_renewed);
      return problemResponse(401, ApiErrorCode.invalidCredentials);
    };

    await expectLater(
      client.post('/v1/auth/login', {}, (json) => json),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.invalidCredentials,
        ),
      ),
    );
    expect(refreshes(), isEmpty);
    expect(sessionStore.session, _expired);
  });
}
