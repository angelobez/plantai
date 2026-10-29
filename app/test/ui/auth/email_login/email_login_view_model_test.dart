import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/ui/auth/email_login/view_models/email_login_view_model.dart';

import '../../../testing/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late EmailLoginViewModel viewModel;

  setUp(() {
    repository = FakeAuthRepository();
    viewModel = EmailLoginViewModel(authRepository: repository);
  });

  Future<EmailLoginResult> submit({
    String email = 'marina@email.com',
    String password = 'senha-boa-123',
  }) => viewModel.submit(email: email, password: password);

  test('logs in with the trimmed e-mail and the password as typed', () async {
    final result = await submit(
      email: ' marina@email.com ',
      password: ' senha-boa-123',
    );

    expect(result, EmailLoginResult.signedIn);
    expect(repository.calls, ['logIn(marina@email.com,  senha-boa-123)']);
    expect(repository.isSignedIn, isTrue);
    expect(viewModel.error, isNull);
  });

  test('checks the e-mail and the password before calling the API', () async {
    final result = await submit(email: 'marina', password: '');

    expect(result, EmailLoginResult.failed);
    expect(repository.calls, isEmpty);
    expect(viewModel.emailError, 'Informe um e-mail válido.');
    expect(viewModel.passwordError, 'Informe a sua senha.');
  });

  test('a password shorter than 8 still goes to the API', () async {
    // Not a sign-up: a short password is just a wrong one, and the API says so.
    expect(await submit(password: '1234'), EmailLoginResult.signedIn);
    expect(viewModel.passwordError, isNull);
  });

  test('a field error goes away once the field is fixed', () async {
    await submit(email: 'marina');
    expect(viewModel.emailError, isNotNull);

    await submit();
    expect(viewModel.emailError, isNull);
  });

  test('is submitting while the API answers', () async {
    repository.gate = Completer();
    final notifications = <bool>[];
    viewModel.addListener(() => notifications.add(viewModel.isSubmitting));

    final result = submit();
    expect(viewModel.isSubmitting, isTrue);

    repository.gate!.complete();
    await result;
    expect(viewModel.isSubmitting, isFalse);
    expect(notifications, [true, false]);
  });

  test(
    'an unconfirmed e-mail goes to the code screen, with no error',
    () async {
      repository.failure = AuthFailure.emailNotVerified;

      final result = await submit();

      expect(result, EmailLoginResult.verifyEmail);
      expect(viewModel.error, isNull);
      expect(repository.pendingEmail, 'marina@email.com');
      expect(repository.isSignedIn, isFalse);
    },
  );

  for (final (failure, message) in [
    (AuthFailure.invalidCredentials, 'E-mail ou senha incorretos.'),
    (
      AuthFailure.noConnection,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    ),
    (
      AuthFailure.tooManyRequests,
      'Muitas tentativas. Espere alguns minutos e tente de novo.',
    ),
    (AuthFailure.validationFailed, 'Confira os dados e tente de novo.'),
    (AuthFailure.unknown, 'Algo deu errado. Tente de novo.'),
  ]) {
    test('${failure.name} becomes "$message"', () async {
      repository.failure = failure;

      expect(await submit(), EmailLoginResult.failed);
      expect(viewModel.error, message);
      expect(viewModel.isSubmitting, isFalse);
    });
  }

  test('a new attempt clears the previous error', () async {
    repository.failure = AuthFailure.invalidCredentials;
    await submit();
    repository.failure = null;

    await submit();

    expect(viewModel.error, isNull);
  });
}
