import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/photo/photo_repository_remote.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/photo_picker/photo_picker.dart';
import 'package:plantai/data/services/session/session_store.dart';
import 'package:plantai/domain/models/photo_failure.dart';

import '../../../testing/fake_http_client_adapter.dart';

final _picked = PickedPhoto(
  bytes: Uint8List.fromList(utf8.encode('jpeg-bytes')),
  filename: 'IMG_0042.jpg',
);

const _photoJson = {
  'id': '0190e0d4-0000-7000-8000-0000000000aa',
  'url': 'http://localhost:9000/plantai-photos/photos/aa.jpg?X-Amz-Signature=1',
  'expiresAt': '2026-11-03T15:00:00.000Z',
};

void main() {
  late FakeHttpClientAdapter adapter;
  late PhotoRepositoryRemote repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = FakeHttpClientAdapter((_) async => jsonResponse(201, _photoJson));
    repository = PhotoRepositoryRemote(
      apiClient: ApiClient(
        baseUrl: 'http://api.test',
        appVersion: '0.2.0',
        updateRequired: UpdateRequired(),
        sessionStore: await SessionStore.load(),
        httpClientAdapter: adapter,
      ),
    );
  });

  test('upload posts the photo as the multipart file field', () async {
    final photo = await repository.upload(_picked);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/photos');
    final body = utf8.decode(await adapter.bodies.single);
    expect(body, contains('name="file"; filename="IMG_0042.jpg"'));
    expect(body, contains('content-type: image/jpeg'));
    expect(body, contains('jpeg-bytes'));

    expect(photo.id, _photoJson['id']);
    expect(photo.url, _photoJson['url']);
    expect(photo.expiresAt, DateTime.utc(2026, 11, 3, 15));
  });

  test('no connection becomes PhotoFailure.noConnection', () async {
    adapter.respond = (options) async => throw DioException.connectionError(
      requestOptions: options,
      reason: 'refused',
    );

    await expectLater(
      repository.upload(_picked),
      throwsA(PhotoFailure.noConnection),
    );
  });

  for (final (code, status, failure) in [
    ('PHOTO_DAILY_LIMIT', 429, PhotoFailure.dailyLimit),
    ('VALIDATION_FAILED', 400, PhotoFailure.notAnImage),
    ('INTERNAL_ERROR', 500, PhotoFailure.unknown),
  ]) {
    test('$code becomes $failure', () async {
      adapter.respond = (_) async => problemResponse(status, code);

      await expectLater(repository.upload(_picked), throwsA(failure));
    });
  }
}
