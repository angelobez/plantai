import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/ui/auth/password_reset/view_models/password_reset_view_model.dart';

import '../../../testing/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late List<PasswordResetViewModel> created;

  setUp(() {
    repository = FakeAuthRepository();
    created = [];
  });

  // Stops the countdown timers.
  tearDown(() {
    for (final viewModel in created) {
      viewModel.dispose();
    }
  });

  PasswordResetViewModel create() {
    final viewModel = PasswordResetViewModel(authRepository: repository);
    created.add(viewModel);
    return viewModel;
  }

  /// A ViewModel already on the code step for marina@email.com.
  Future<PasswordResetViewModel> onCodeStep() async {
    final viewModel = create();
    await viewModel.requestCode(' marina@email.com ');
    repository.calls.clear();
    return viewModel;
  }

  group('e-mail step', () {
    test('starts there, with nothing sent', () {
      final viewModel = create();

      expect(viewModel.step, PasswordResetStep.email);
      expect(repository.calls, isEmpty);
    });

    test(
      'asks for the code with the trimmed e-mail and goes to the code step',
      () async {
        final viewModel = create();

        await viewModel.requestCode(' marina@email.com ');

        expect(repository.calls, ['requestPasswordReset(marina@email.com)']);
        expect(viewModel.step, PasswordResetStep.code);
        expect(viewModel.email, 'marina@email.com');
        expect(viewModel.error, isNull);
      },
    );

    test('checks the e-mail before calling the API', () async {
      final viewModel = create();

      await viewModel.requestCode('marina');

      expect(viewModel.emailError, 'Informe um e-mail válido.');
      expect(viewModel.step, PasswordResetStep.email);
      expect(repository.calls, isEmpty);
    });

    test('is submitting while the API answers', () async {
      final viewModel = create();
      repository.gate = Completer();

      final result = viewModel.requestCode('marina@email.com');
      expect(viewModel.isSubmitting, isTrue);

      repository.gate!.complete();
      await result;
      expect(viewModel.isSubmitting, isFalse);
    });

    for (final (failure, message) in [
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
      test('$failure stays on the e-mail step with "$message"', () async {
        final viewModel = create();
        repository.failure = failure;

        await viewModel.requestCode('marina@email.com');

        expect(viewModel.error, message);
        expect(viewModel.step, PasswordResetStep.email);
      });
    }
  });

  group('code step', () {
    test('sets the new password with the code, which signs in', () async {
      final viewModel = await onCodeStep();

      await viewModel.confirm(code: '123456', newPassword: 'senha-nova-456');

      expect(repository.calls, [
        'resetPassword(marina@email.com, 123456, senha-nova-456)',
      ]);
      expect(repository.isSignedIn, isTrue);
      expect(viewModel.error, isNull);
    });

    test(
      'checks the code and the new password before calling the API',
      () async {
        final viewModel = await onCodeStep();

        await viewModel.confirm(code: '123', newPassword: 'curta');

        expect(viewModel.codeError, 'Digite os 6 dígitos do código.');
        expect(
          viewModel.passwordError,
          'A senha precisa ter pelo menos 8 caracteres.',
        );
        expect(repository.calls, isEmpty);
      },
    );

    test('a new password over 128 characters is refused', () async {
      final viewModel = await onCodeStep();

      await viewModel.confirm(code: '123456', newPassword: 'a' * 129);

      expect(viewModel.passwordError, 'Use até 128 caracteres.');
      expect(repository.calls, isEmpty);
    });

    test('is submitting while the API answers', () async {
      final viewModel = await onCodeStep();
      repository.gate = Completer();

      final result = viewModel.confirm(
        code: '123456',
        newPassword: 'senha-nova-456',
      );
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
      (AuthFailure.validationFailed, 'Confira os dados e tente de novo.'),
      (
        AuthFailure.noConnection,
        'Sem conexão com a internet. Confira a rede e tente de novo.',
      ),
      (AuthFailure.unknown, 'Algo deu errado. Tente de novo.'),
    ]) {
      test('$failure shows "$message"', () async {
        final viewModel = await onCodeStep();
        repository.failure = failure;

        await viewModel.confirm(code: '123456', newPassword: 'senha-nova-456');

        expect(viewModel.error, message);
        expect(repository.isSignedIn, isFalse);
      });
    }

    test('"Corrigir o e-mail" goes back to the e-mail step', () async {
      final viewModel = await onCodeStep();
      repository.failure = AuthFailure.invalidCode;
      await viewModel.confirm(code: '123456', newPassword: 'senha-nova-456');

      viewModel.editEmail();

      expect(viewModel.step, PasswordResetStep.email);
      expect(viewModel.error, isNull);
    });

    test('a new code can be asked for only after the countdown', () {
      fakeAsync((async) {
        final viewModel = create();
        viewModel.requestCode('marina@email.com');
        async.flushMicrotasks();

        expect(viewModel.resendSecondsLeft, 45);
        expect(viewModel.canResend, isFalse);
        viewModel.resend();
        async.flushMicrotasks();
        expect(repository.calls, hasLength(1));

        async.elapse(const Duration(seconds: 45));
        expect(viewModel.canResend, isTrue);

        viewModel.resend();
        async.flushMicrotasks();
        expect(repository.calls, [
          'requestPasswordReset(marina@email.com)',
          'requestPasswordReset(marina@email.com)',
        ]);
        expect(viewModel.notice, 'Enviamos um código novo.');
        expect(viewModel.resendSecondsLeft, 45);
      });
    });

    test('a failed resend shows the message', () {
      fakeAsync((async) {
        final viewModel = create();
        viewModel.requestCode('marina@email.com');
        async.elapse(const Duration(seconds: 45));
        repository.failure = AuthFailure.tooManyRequests;

        viewModel.resend();
        async.flushMicrotasks();

        expect(
          viewModel.error,
          'Muitas tentativas. Espere alguns minutos e tente de novo.',
        );
        expect(viewModel.notice, isNull);
      });
    });
  });

  group('without connection', () {
    test('retry asks for the code again', () async {
      final viewModel = create();
      repository.failure = AuthFailure.noConnection;
      await viewModel.requestCode('marina@email.com');
      expect(viewModel.canRetry, isTrue);

      repository.failure = null;
      await viewModel.retry();

      expect(repository.calls, [
        'requestPasswordReset(marina@email.com)',
        'requestPasswordReset(marina@email.com)',
      ]);
      expect(viewModel.step, PasswordResetStep.code);
      expect(viewModel.canRetry, isFalse);
    });

    test('retry sends the same code and password again', () async {
      final viewModel = await onCodeStep();
      repository.failure = AuthFailure.noConnection;
      await viewModel.confirm(code: '123456', newPassword: 'senha-nova-456');
      expect(viewModel.canRetry, isTrue);

      repository.failure = null;
      await viewModel.retry();

      expect(repository.calls, [
        'resetPassword(marina@email.com, 123456, senha-nova-456)',
        'resetPassword(marina@email.com, 123456, senha-nova-456)',
      ]);
      expect(viewModel.canRetry, isFalse);
    });

    test('a wrong code offers no retry', () async {
      final viewModel = await onCodeStep();
      repository.failure = AuthFailure.invalidCode;
      await viewModel.confirm(code: '123456', newPassword: 'senha-nova-456');

      expect(viewModel.canRetry, isFalse);
    });
  });
}
