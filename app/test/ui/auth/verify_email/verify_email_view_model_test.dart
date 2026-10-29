import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/ui/auth/verify_email/view_models/verify_email_view_model.dart';

import '../../../testing/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late List<VerifyEmailViewModel> created;

  setUp(() {
    repository = FakeAuthRepository(pendingEmail: 'marina@email.com');
    created = [];
  });

  // Stops the countdown timers.
  tearDown(() {
    for (final viewModel in created) {
      viewModel.dispose();
    }
  });

  VerifyEmailViewModel create() {
    final viewModel = VerifyEmailViewModel(authRepository: repository);
    created.add(viewModel);
    return viewModel;
  }

  test('shows the e-mail waiting for the code', () {
    expect(create().email, 'marina@email.com');
  });

  test('confirms the code, which signs the User in', () async {
    final viewModel = create();

    await viewModel.submit('123456');

    expect(repository.calls, ['verifyEmail(123456)']);
    expect(repository.isSignedIn, isTrue);
    expect(viewModel.error, isNull);
  });

  test('checks the 6 digits before calling the API', () async {
    final viewModel = create();

    for (final code in ['', '12345', '12345a', '1234567']) {
      await viewModel.submit(code);
      expect(viewModel.codeError, 'Digite os 6 dígitos do código.');
    }
    expect(repository.calls, isEmpty);
  });

  test('is submitting while the API answers', () async {
    final viewModel = create();
    repository.gate = Completer();

    final result = viewModel.submit('123456');
    expect(viewModel.isSubmitting, isTrue);
    expect(viewModel.canResend, isFalse);

    repository.gate!.complete();
    await result;
    expect(viewModel.isSubmitting, isFalse);
  });

  for (final (failure, message) in [
    (
      AuthFailure.invalidCode,
      'Código errado ou vencido. Confira o e-mail ou peça um novo.',
    ),
    (
      AuthFailure.tooManyRequests,
      'Muitas tentativas. Espere alguns minutos e tente de novo.',
    ),
    (
      AuthFailure.noConnection,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    ),
    (AuthFailure.unknown, 'Algo deu errado. Tente de novo.'),
  ]) {
    test('${failure.name} becomes "$message"', () async {
      final viewModel = create();
      repository.failure = failure;

      await viewModel.submit('123456');

      expect(viewModel.error, message);
      expect(repository.isSignedIn, isFalse);
    });
  }

  group('resend', () {
    test('waits 45 seconds after the first code, counting down', () {
      fakeAsync((async) {
        final viewModel = create();
        expect(viewModel.canResend, isFalse);
        expect(viewModel.resendSecondsLeft, 45);

        async.elapse(const Duration(seconds: 44));
        expect(viewModel.resendSecondsLeft, 1);
        expect(viewModel.canResend, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(viewModel.resendSecondsLeft, 0);
        expect(viewModel.canResend, isTrue);
      });
    });

    test('asks for a new code, says so and waits again', () {
      fakeAsync((async) {
        final viewModel = create();
        async.elapse(const Duration(seconds: 45));

        viewModel.resend();
        async.flushMicrotasks();

        expect(repository.calls, ['resendCode()']);
        expect(viewModel.notice, 'Enviamos um código novo.');
        expect(viewModel.resendSecondsLeft, 45);
        expect(viewModel.canResend, isFalse);
      });
    });

    test('does nothing while it has to wait', () async {
      final viewModel = create();

      await viewModel.resend();

      expect(repository.calls, isEmpty);
    });

    test('a failure shows its message and lets the User try again', () {
      fakeAsync((async) {
        final viewModel = create();
        async.elapse(const Duration(seconds: 45));
        repository.failure = AuthFailure.tooManyRequests;

        viewModel.resend();
        async.flushMicrotasks();

        expect(
          viewModel.error,
          'Muitas tentativas. Espere alguns minutos e tente de novo.',
        );
        expect(viewModel.notice, isNull);
        expect(viewModel.canResend, isTrue);
      });
    });
  });
}
