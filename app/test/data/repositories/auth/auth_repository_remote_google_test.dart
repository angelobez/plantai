import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/auth/auth_repository_remote.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/google/google_id_tokens.dart';
import 'package:plantai/data/services/session/session_store.dart';
import 'package:plantai/domain/models/auth_failure.dart';

import '../../../testing/fake_google_id_tokens.dart';
import '../../../testing/fake_http_client_adapter.dart';

Map<String, Object?> tokensJson() => {
  'accessToken': 'access-1',
  'refreshToken': 'refresh-1',
  'user': {
    'id': '0190d6b4-0000-7000-8000-000000000001',
    'name': 'Marina Souza',
    'email': 'marina@gmail.com',
    'phone': null,
    'donationLocation': null,
  },
};

void main() {
  late FakeHttpClientAdapter adapter;
  late FakeGoogleIdTokens google;
  late SessionStore sessionStore;
  late AuthRepositoryRemote repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = FakeHttpClientAdapter(
      (_) async => jsonResponse(200, tokensJson()),
    );
    google = FakeGoogleIdTokens();
    sessionStore = await SessionStore.load();
    repository = AuthRepositoryRemote(
      apiClient: ApiClient(
        baseUrl: 'http://api.test',
        appVersion: '0.1.0',
        updateRequired: UpdateRequired(),
        sessionStore: sessionStore,
        httpClientAdapter: adapter,
      ),
      sessionStore: sessionStore,
      googleIdTokens: google,
    );
  });

  test(
    'signInWithGoogle sends the ID token, saves the tokens and notifies',
    () async {
      var notified = 0;
      repository.addListener(() => notified++);

      await repository.signInWithGoogle();

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v1/auth/google');
      expect(request.data, {'idToken': 'google-id-token'});
      expect(repository.isSignedIn, isTrue);
      expect(notified, 1);
      final reloaded = await SessionStore.load();
      expect(
        reloaded.session,
        const Session(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
    },
  );

  test('canceling the account picker calls nothing and stays out', () async {
    google.idToken = null;

    await repository.signInWithGoogle();

    expect(adapter.requests, isEmpty);
    expect(repository.isSignedIn, isFalse);
  });

  test('Google Sign-In failing becomes googleUnavailable', () async {
    google.error = const GoogleIdTokenUnavailable('clientConfigurationError');

    await expectLater(
      repository.signInWithGoogle(),
      throwsA(AuthFailure.googleUnavailable),
    );
    expect(adapter.requests, isEmpty);
  });

  for (final (code, failure) in [
    ('GOOGLE_ACCOUNT_LINK_REFUSED', AuthFailure.googleAccountLinkRefused),
    ('INVALID_CREDENTIALS', AuthFailure.invalidCredentials),
  ]) {
    test('$code from the API becomes ${failure.name}', () async {
      adapter.respond = (_) async => problemResponse(409, code);

      await expectLater(repository.signInWithGoogle(), throwsA(failure));
      expect(repository.isSignedIn, isFalse);
    });
  }

  test('no connection', () async {
    adapter.respond = (options) async => throw DioException.connectionError(
      requestOptions: options,
      reason: 'refused',
    );

    await expectLater(
      repository.signInWithGoogle(),
      throwsA(AuthFailure.noConnection),
    );
  });
}
