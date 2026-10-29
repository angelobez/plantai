import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/ui/auth/login/view_models/login_view_model.dart';

import '../../../testing/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late LoginViewModel viewModel;

  setUp(() {
    repository = FakeAuthRepository();
    viewModel = LoginViewModel(authRepository: repository);
  });

  test('"Entrar com Google" signs in', () async {
    await viewModel.signInWithGoogle();

    expect(repository.calls, ['signInWithGoogle()']);
    expect(repository.isSignedIn, isTrue);
    expect(viewModel.error, isNull);
  });

  test('canceling the account picker shows no error', () async {
    repository.googleCanceled = true;

    await viewModel.signInWithGoogle();

    expect(repository.isSignedIn, isFalse);
    expect(viewModel.error, isNull);
    expect(viewModel.isSigningInWithGoogle, isFalse);
  });

  test('is signing in while Google and the API answer', () async {
    repository.gate = Completer();
    final notifications = <bool>[];
    viewModel.addListener(
      () => notifications.add(viewModel.isSigningInWithGoogle),
    );

    final result = viewModel.signInWithGoogle();
    expect(viewModel.isSigningInWithGoogle, isTrue);

    repository.gate!.complete();
    await result;
    expect(viewModel.isSigningInWithGoogle, isFalse);
    expect(notifications, [true, false]);
  });

  test('a tap while signing in is ignored', () async {
    repository.gate = Completer();
    final first = viewModel.signInWithGoogle();

    await viewModel.signInWithGoogle();
    repository.gate!.complete();
    await first;

    expect(repository.calls, ['signInWithGoogle()']);
  });

  for (final (failure, message) in [
    (
      AuthFailure.googleAccountLinkRefused,
      'Este e-mail já tem conta no PlantAí. Entre com a sua senha.',
    ),
    (
      AuthFailure.googleUnavailable,
      'Não deu para entrar com o Google. Tente de novo ou entre com e-mail.',
    ),
    (
      AuthFailure.noConnection,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    ),
    (
      AuthFailure.tooManyRequests,
      'Muitas tentativas. Espere alguns minutos e tente de novo.',
    ),
    (AuthFailure.invalidCredentials, 'Algo deu errado. Tente de novo.'),
    (AuthFailure.unknown, 'Algo deu errado. Tente de novo.'),
  ]) {
    test('${failure.name} becomes "$message"', () async {
      repository.failure = failure;

      await viewModel.signInWithGoogle();

      expect(viewModel.error, message);
      expect(viewModel.isSigningInWithGoogle, isFalse);
    });
  }

  test('a new attempt clears the previous error', () async {
    repository.failure = AuthFailure.googleAccountLinkRefused;
    await viewModel.signInWithGoogle();
    repository.failure = null;
    repository.gate = Completer();

    final result = viewModel.signInWithGoogle();

    expect(viewModel.error, isNull);
    repository.gate!.complete();
    await result;
  });
}
