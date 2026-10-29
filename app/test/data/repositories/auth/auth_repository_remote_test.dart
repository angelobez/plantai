import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/auth/auth_repository_remote.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/session/session_store.dart';
import 'package:plantai/domain/models/auth_failure.dart';

import '../../../testing/fake_http_client_adapter.dart';

Map<String, Object?> tokensJson({String access = 'access-1'}) => {
  'accessToken': access,
  'refreshToken': 'refresh-1',
  'user': {
    'id': '0190d6b4-0000-7000-8000-000000000001',
    'name': 'Marina Souza',
    'email': 'marina@email.com',
    'phone': null,
    'donationLocation': null,
  },
};

void main() {
  late FakeHttpClientAdapter adapter;
  late SessionStore sessionStore;
  late AuthRepositoryRemote repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = FakeHttpClientAdapter(
      (_) async => ResponseBody.fromString('', 202),
    );
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
    );
  });

  Future<void> signUp() => repository.signUp(
    name: 'Marina Souza',
    email: 'marina@email.com',
    password: 'senha-boa-123',
  );

  test('starts signed out when nothing was saved', () {
    expect(repository.isSignedIn, isFalse);
    expect(repository.pendingEmail, isNull);
  });

  test('starts signed in when a session was saved by the last run', () async {
    FlutterSecureStorage.setMockInitialValues({
      'session.accessToken': 'a',
      'session.refreshToken': 'r',
    });
    final saved = await SessionStore.load();
    final restored = AuthRepositoryRemote(
      apiClient: ApiClient(
        baseUrl: 'http://api.test',
        appVersion: '0.1.0',
        updateRequired: UpdateRequired(),
        sessionStore: saved,
        httpClientAdapter: adapter,
      ),
      sessionStore: saved,
    );

    expect(restored.isSignedIn, isTrue);
    expect(adapter.requests, isEmpty);
  });

  test('signUp posts the account and waits for the code', () async {
    await signUp();

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/auth/signup');
    expect(request.data, {
      'name': 'Marina Souza',
      'email': 'marina@email.com',
      'password': 'senha-boa-123',
    });
    expect(repository.pendingEmail, 'marina@email.com');
    expect(repository.isSignedIn, isFalse);
  });

  test('resendCode signs up again with the same data', () async {
    await signUp();

    await repository.resendCode();

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.path, '/v1/auth/signup');
    expect(adapter.requests.last.data, adapter.requests.first.data);
  });

  test('verifyEmail signs in, saves the tokens and notifies', () async {
    await signUp();
    adapter.respond = (_) async => jsonResponse(200, tokensJson());
    var notified = 0;
    repository.addListener(() => notified++);

    await repository.verifyEmail('123456');

    expect(adapter.requests.last.path, '/v1/auth/verify-email');
    expect(adapter.requests.last.data, {
      'email': 'marina@email.com',
      'code': '123456',
    });
    expect(repository.isSignedIn, isTrue);
    expect(repository.pendingEmail, isNull);
    expect(notified, 1);
    final reloaded = await SessionStore.load();
    expect(
      reloaded.session,
      const Session(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );
  });

  test('later calls carry the new access token', () async {
    await signUp();
    adapter.respond = (_) async => jsonResponse(200, tokensJson());
    await repository.verifyEmail('123456');

    await repository.signUp(name: 'x', email: 'y@email.com', password: 'z');

    expect(adapter.requests.last.headers['Authorization'], 'Bearer access-1');
  });

  group('logIn', () {
    Future<void> logIn() =>
        repository.logIn(email: 'marina@email.com', password: 'senha-boa-123');

    test('posts e-mail and password, saves the tokens and notifies', () async {
      adapter.respond = (_) async => jsonResponse(200, tokensJson());
      var notified = 0;
      repository.addListener(() => notified++);

      await logIn();

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v1/auth/login');
      expect(request.data, {
        'email': 'marina@email.com',
        'password': 'senha-boa-123',
      });
      expect(repository.isSignedIn, isTrue);
      expect(notified, 1);
      final reloaded = await SessionStore.load();
      expect(
        reloaded.session,
        const Session(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
    });

    test('wrong credentials stay signed out, with no e-mail waiting', () async {
      adapter.respond = (_) async =>
          problemResponse(401, 'INVALID_CREDENTIALS');

      await expectLater(logIn(), throwsA(AuthFailure.invalidCredentials));
      expect(repository.isSignedIn, isFalse);
      expect(repository.pendingEmail, isNull);
    });

    test('an unconfirmed e-mail waits for the code the API sent', () async {
      adapter.respond = (_) async => problemResponse(403, 'EMAIL_NOT_VERIFIED');

      await expectLater(logIn(), throwsA(AuthFailure.emailNotVerified));
      expect(repository.isSignedIn, isFalse);
      expect(repository.pendingEmail, 'marina@email.com');
    });

    test(
      'resendCode after EMAIL_NOT_VERIFIED logs in again for a new code',
      () async {
        adapter.respond = (_) async =>
            problemResponse(403, 'EMAIL_NOT_VERIFIED');
        await expectLater(logIn(), throwsA(AuthFailure.emailNotVerified));

        await repository.resendCode();

        expect(adapter.requests, hasLength(2));
        expect(adapter.requests.last.path, '/v1/auth/login');
        expect(adapter.requests.last.data, adapter.requests.first.data);
        expect(repository.pendingEmail, 'marina@email.com');
      },
    );

    test('resendCode still fails for any other answer', () async {
      adapter.respond = (_) async => problemResponse(403, 'EMAIL_NOT_VERIFIED');
      await expectLater(logIn(), throwsA(AuthFailure.emailNotVerified));
      adapter.respond = (_) async => problemResponse(429, 'TOO_MANY_REQUESTS');

      await expectLater(
        repository.resendCode(),
        throwsA(AuthFailure.tooManyRequests),
      );
    });

    test('the code after EMAIL_NOT_VERIFIED signs in', () async {
      adapter.respond = (_) async => problemResponse(403, 'EMAIL_NOT_VERIFIED');
      await expectLater(logIn(), throwsA(AuthFailure.emailNotVerified));
      adapter.respond = (_) async => jsonResponse(200, tokensJson());

      await repository.verifyEmail('123456');

      expect(adapter.requests.last.path, '/v1/auth/verify-email');
      expect(adapter.requests.last.data, {
        'email': 'marina@email.com',
        'code': '123456',
      });
      expect(repository.isSignedIn, isTrue);
    });
  });

  group('turns the API answer into an AuthFailure', () {
    for (final (code, failure) in [
      ('INVALID_CODE', AuthFailure.invalidCode),
      ('TOO_MANY_REQUESTS', AuthFailure.tooManyRequests),
      ('VALIDATION_FAILED', AuthFailure.validationFailed),
      ('INVALID_CREDENTIALS', AuthFailure.invalidCredentials),
      ('EMAIL_NOT_VERIFIED', AuthFailure.emailNotVerified),
      ('GOOGLE_ACCOUNT_LINK_REFUSED', AuthFailure.googleAccountLinkRefused),
      ('APP_UPDATE_REQUIRED', AuthFailure.updateRequired),
      ('SOMETHING_NEW', AuthFailure.unknown),
    ]) {
      test(code, () async {
        await signUp();
        adapter.respond = (_) async => problemResponse(400, code);

        await expectLater(repository.verifyEmail('123456'), throwsA(failure));
        expect(repository.isSignedIn, isFalse);
      });
    }

    test('no connection', () async {
      adapter.respond = (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
      );

      await expectLater(signUp(), throwsA(AuthFailure.noConnection));
      expect(repository.pendingEmail, isNull);
    });
  });
}
