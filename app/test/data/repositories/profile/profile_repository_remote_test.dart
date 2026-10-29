import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/profile/profile_repository_remote.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/session/session_store.dart';
import 'package:plantai/domain/models/profile_failure.dart';

import '../../../testing/fake_http_client_adapter.dart';

Map<String, Object?> profileJson({String name = 'Marina Souza'}) => {
  'id': '0190d6b4-0000-7000-8000-000000000001',
  'name': name,
  'email': 'marina@email.com',
  'phone': null,
  'donationLocation': null,
};

void main() {
  late FakeHttpClientAdapter adapter;
  late ProfileRepositoryRemote repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = FakeHttpClientAdapter(
      (_) async => jsonResponse(200, profileJson()),
    );
    repository = ProfileRepositoryRemote(
      apiClient: ApiClient(
        baseUrl: 'http://api.test',
        appVersion: '0.1.0',
        updateRequired: UpdateRequired(),
        sessionStore: await SessionStore.load(),
        httpClientAdapter: adapter,
      ),
    );
  });

  test('fetchProfile reads /v1/me', () async {
    final profile = await repository.fetchProfile();

    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/v1/me');
    expect(profile.name, 'Marina Souza');
    expect(profile.email, 'marina@email.com');
    expect(profile.phone, isNull);
    expect(profile.donationLocation, isNull);
  });

  test('updateName patches /v1/me and returns what the API saved', () async {
    adapter.respond = (_) async => jsonResponse(200, profileJson(name: 'Mari'));

    final profile = await repository.updateName('Mari');

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/v1/me');
    expect(request.data, {'name': 'Mari'});
    expect(profile.name, 'Mari');
  });

  test('no connection becomes ProfileFailure.noConnection', () async {
    adapter.respond = (options) async => throw DioException.connectionError(
      requestOptions: options,
      reason: 'refused',
    );

    await expectLater(
      repository.fetchProfile(),
      throwsA(ProfileFailure.noConnection),
    );
  });

  test('an error answer becomes ProfileFailure.unknown', () async {
    adapter.respond = (_) async => problemResponse(400, 'VALIDATION_FAILED');

    await expectLater(
      repository.updateName(''),
      throwsA(ProfileFailure.unknown),
    );
  });
}
