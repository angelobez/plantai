import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/api_exception.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/session/session_store.dart';

import '../../../testing/fake_http_client_adapter.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late UpdateRequired updateRequired;
  late SessionStore sessionStore;
  late ApiClient client;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = FakeHttpClientAdapter((_) async => jsonResponse(200, {}));
    updateRequired = UpdateRequired();
    sessionStore = await SessionStore.load();
    client = ApiClient(
      baseUrl: 'http://api.test',
      appVersion: '0.1.0',
      updateRequired: updateRequired,
      sessionStore: sessionStore,
      httpClientAdapter: adapter,
    );
  });

  test('returns the parsed body', () async {
    adapter.respond = (_) async => jsonResponse(200, {'name': 'Marina'});

    final name = await client.get('/v1/me', (json) => json['name']);

    expect(name, 'Marina');
    expect(adapter.requests.single.path, '/v1/me');
  });

  test('sends the app version on every request', () async {
    await client.get('/v1/me', (json) => json);

    expect(adapter.requests.single.headers['X-App-Version'], '0.1.0');
  });

  test('an error answer becomes an ApiException with its code', () async {
    adapter.respond = (_) async => problemResponse(422, 'VALIDATION_FAILED');

    await expectLater(
      client.get('/v1/me', (json) => json),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 422)
            .having((e) => e.code, 'code', ApiErrorCode.validationFailed),
      ),
    );
    expect(updateRequired.isRequired, isFalse);
  });

  test('a 2xx problem answer (202 CARE_GUIDE_GENERATING) is an ApiException with its Retry-After', () async {
    adapter.respond = (_) async => ResponseBody.fromString(
      jsonEncode({
        'type': 'about:blank',
        'title': 'Accepted',
        'status': 202,
        'code': 'CARE_GUIDE_GENERATING',
      }),
      202,
      headers: {
        Headers.contentTypeHeader: ['application/problem+json; charset=utf-8'],
        'retry-after': ['3'],
      },
    );

    await expectLater(
      client.get('/v1/species/1', (json) => json),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 202)
            .having((e) => e.code, 'code', ApiErrorCode.careGuideGenerating)
            .having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 3),
            ),
      ),
    );
  });

  test('an error without Retry-After has no retryAfter', () async {
    adapter.respond = (_) async => problemResponse(404, 'NOT_FOUND');

    await expectLater(
      client.get('/v1/species/1', (json) => json),
      throwsA(
        isA<ApiException>().having((e) => e.retryAfter, 'retryAfter', isNull),
      ),
    );
  });

  test('a call may wait longer than the usual receive timeout', () async {
    await client.get(
      '/v1/species/1',
      (json) => json,
      receiveTimeout: const Duration(seconds: 60),
    );

    expect(adapter.requests.single.receiveTimeout, const Duration(seconds: 60));
  });

  test('a network failure becomes an ApiConnectionException', () async {
    adapter.respond = (options) async => throw DioException.connectionError(
      requestOptions: options,
      reason: 'refused',
    );

    await expectLater(
      client.get('/v1/me', (json) => json),
      throwsA(isA<ApiConnectionException>()),
    );
  });

  test('426 APP_UPDATE_REQUIRED raises the update signal', () async {
    adapter.respond = (_) async =>
        problemResponse(426, ApiErrorCode.appUpdateRequired.wire!);
    var notified = 0;
    updateRequired.addListener(() => notified++);

    await expectLater(
      client.get('/v1/me', (json) => json),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.appUpdateRequired,
        ),
      ),
    );
    expect(updateRequired.isRequired, isTrue);
    expect(notified, 1);
  });

  test('a 426 without the code does not raise the signal', () async {
    adapter.respond = (_) async => jsonResponse(426, {'message': 'proxy'});

    await expectLater(
      client.get('/v1/me', (json) => json),
      throwsA(isA<ApiException>()),
    );
    expect(updateRequired.isRequired, isFalse);
  });

  test('sends the access token as Bearer when there is a session', () async {
    await sessionStore.save(
      const Session(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );

    await client.get('/v1/me', (json) => json);

    expect(adapter.requests.single.headers['Authorization'], 'Bearer access-1');
  });

  test('sends no Authorization without a session', () async {
    await client.get('/v1/me', (json) => json);

    expect(adapter.requests.single.headers, isNot(contains('Authorization')));
  });

  test('post sends the JSON body and parses the answer', () async {
    adapter.respond = (_) async => jsonResponse(200, {'ok': true});

    final ok = await client.post('/v1/auth/verify-email', {
      'email': 'marina@email.com',
      'code': '123456',
    }, (json) => json['ok']);

    expect(ok, isTrue);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/auth/verify-email');
    expect(jsonDecode(jsonEncode(request.data)), {
      'email': 'marina@email.com',
      'code': '123456',
    });
  });

  test('postWithoutBody accepts an empty 202', () async {
    adapter.respond = (_) async => ResponseBody.fromString('', 202);

    await client.postWithoutBody('/v1/auth/signup', {'name': 'Marina'});

    expect(adapter.requests.single.method, 'POST');
  });

  test('post turns an error answer into an ApiException', () async {
    adapter.respond = (_) async => problemResponse(400, 'INVALID_CODE');

    await expectLater(
      client.postWithoutBody('/v1/auth/verify-email', {}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.invalidCode,
        ),
      ),
    );
  });

  test('a code the app does not know, or none, is unknown', () async {
    adapter.respond = (_) async => problemResponse(400, 'SOMETHING_NEW');

    await expectLater(
      client.postWithoutBody('/v1/auth/verify-email', {}),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.unknown),
      ),
    );

    adapter.respond = (_) async => jsonResponse(502, {'message': 'proxy'});

    await expectLater(
      client.postWithoutBody('/v1/auth/verify-email', {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 502)
            .having((e) => e.code, 'code', ApiErrorCode.unknown),
      ),
    );
  });

  test('patch sends the JSON body and parses the answer', () async {
    adapter.respond = (_) async => jsonResponse(200, {'name': 'Marina'});

    final name = await client.patch('/v1/me', {
      'name': 'Marina',
    }, (json) => json['name']);

    expect(name, 'Marina');
    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/v1/me');
    expect(jsonDecode(jsonEncode(request.data)), {'name': 'Marina'});
  });

  test(
    'postMultipart sends the files as multipart and parses the answer',
    () async {
      adapter.respond = (_) async => jsonResponse(201, {'id': 'photo-1'});

      final id = await client.postMultipart('/v1/photos', {
        'file': UploadFile(
          bytes: utf8.encode('jpeg-bytes'),
          filename: 'planta.jpg',
          contentType: 'image/jpeg',
        ),
      }, (json) => json['id']);

      expect(id, 'photo-1');
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v1/photos');
      expect(request.contentType, startsWith('multipart/form-data'));
      final body = utf8.decode(await adapter.bodies.single);
      expect(body, contains('name="file"; filename="planta.jpg"'));
      expect(body, contains('content-type: image/jpeg'));
      expect(body, contains('jpeg-bytes'));
    },
  );

  test('postMultipart turns an error answer into an ApiException', () async {
    adapter.respond = (_) async => problemResponse(429, 'PHOTO_DAILY_LIMIT');

    await expectLater(
      client.postMultipart('/v1/photos', {
        'file': UploadFile(
          bytes: const [1, 2, 3],
          filename: 'planta.jpg',
          contentType: 'image/jpeg',
        ),
      }, (json) => json),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 429)
            .having((e) => e.code, 'code', ApiErrorCode.photoDailyLimit),
      ),
    );
  });

  test('get sends the query parameters', () async {
    await client.get(
      '/v1/species/1',
      (json) => json,
      queryParameters: {'a': 'b'},
    );

    expect(adapter.requests.single.uri.query, 'a=b');
  });

  test('getList sends the query and parses each item of the array', () async {
    adapter.respond = (_) async => jsonResponse(200, [
      {'name': 'jiboia'},
      {'name': 'costela-de-adão'},
    ]);

    final names = await client.getList(
      '/v1/species',
      (json) => json['name'],
      queryParameters: {'q': 'costela de adão'},
    );

    expect(names, ['jiboia', 'costela-de-adão']);
    final request = adapter.requests.single;
    expect(request.path, '/v1/species');
    expect(request.uri.queryParameters, {'q': 'costela de adão'});
  });

  test('getList turns an error answer into an ApiException', () async {
    adapter.respond = (_) async => problemResponse(400, 'VALIDATION_FAILED');

    await expectLater(
      client.getList('/v1/species', (json) => json),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.validationFailed,
        ),
      ),
    );
  });

  test(
    'getList turns a network failure into an ApiConnectionException',
    () async {
      adapter.respond = (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
      );

      await expectLater(
        client.getList('/v1/species', (json) => json),
        throwsA(isA<ApiConnectionException>()),
      );
    },
  );

  test('put sends the JSON body and parses the answer', () async {
    adapter.respond = (_) async => jsonResponse(200, {'phone': '+55'});

    final phone = await client.put('/v1/me/donation-profile', {
      'phone': '11987654321',
    }, (json) => json['phone']);

    expect(phone, '+55');
    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/v1/me/donation-profile');
    expect(jsonDecode(jsonEncode(request.data)), {'phone': '11987654321'});
  });

  test('put turns an error answer into an ApiException', () async {
    adapter.respond = (_) async => problemResponse(400, 'INVALID_PHONE');

    await expectLater(
      client.put('/v1/me/donation-profile', {}, (json) => json),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 400)
            .having((e) => e.code, 'code', ApiErrorCode.invalidPhone),
      ),
    );
  });

  test('get and getList send per-call headers, not in the URL', () async {
    const headers = {'X-Search-Location': '-23.5874,-46.6345'};

    await client.get('/v1/listings/1', (json) => json, headers: headers);
    adapter.respond = (_) async => jsonResponse(200, <Object>[]);
    await client.getList(
      '/v1/listings/nearby',
      (json) => json,
      queryParameters: {'page': '2'},
      headers: headers,
    );

    for (final request in adapter.requests) {
      expect(request.headers['X-Search-Location'], '-23.5874,-46.6345');
      expect(request.uri.toString(), isNot(contains('23.5874')));
      expect(request.headers['X-App-Version'], '0.1.0');
    }
  });

  test('post, patch and put send per-call headers', () async {
    const headers = {'X-Test': 'yes'};

    await client.post('/v1/a', {}, (json) => json, headers: headers);
    await client.patch('/v1/b', {}, (json) => json, headers: headers);
    await client.put('/v1/c', {}, (json) => json, headers: headers);

    expect(adapter.requests.map((r) => r.headers['X-Test']), [
      'yes',
      'yes',
      'yes',
    ]);
  });
}
