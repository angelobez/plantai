import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/api_exception.dart';
import 'package:plantai/data/services/api/update_required.dart';

import '../../../testing/fake_http_client_adapter.dart';

void main() {
  late FakeHttpClientAdapter adapter;
  late UpdateRequired updateRequired;
  late ApiClient client;

  setUp(() {
    adapter = FakeHttpClientAdapter((_) async => jsonResponse(200, {}));
    updateRequired = UpdateRequired();
    client = ApiClient(
      baseUrl: 'http://api.test',
      appVersion: '0.1.0',
      updateRequired: updateRequired,
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
            .having((e) => e.code, 'code', 'VALIDATION_FAILED'),
      ),
    );
    expect(updateRequired.isRequired, isFalse);
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
        problemResponse(426, ApiErrorCode.appUpdateRequired);
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
}
