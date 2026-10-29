import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/ui/auth/signup/view_models/signup_view_model.dart';

import '../../../testing/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late SignupViewModel viewModel;

  setUp(() {
    repository = FakeAuthRepository();
    viewModel = SignupViewModel(authRepository: repository);
  });

  Future<bool> submit({
    String name = 'Marina Souza',
    String email = 'marina@email.com',
    String password = 'senha-boa-123',
  }) => viewModel.submit(name: name, email: email, password: password);

  test('signs up with the trimmed name and e-mail', () async {
    final ok = await submit(
      name: '  Marina Souza ',
      email: ' marina@email.com ',
    );

    expect(ok, isTrue);
    expect(repository.calls, [
      'signUp(Marina Souza, marina@email.com, senha-boa-123)',
    ]);
    expect(viewModel.error, isNull);
  });

  test('checks every field before calling the API', () async {
    final ok = await submit(name: ' ', email: 'marina', password: '1234567');

    expect(ok, isFalse);
    expect(repository.calls, isEmpty);
    expect(viewModel.nameError, 'Informe o seu nome.');
    expect(viewModel.emailError, 'Informe um e-mail válido.');
    expect(
      viewModel.passwordError,
      'A senha precisa ter pelo menos 8 caracteres.',
    );
  });

  test('accepts a password of exactly 8 characters', () async {
    expect(await submit(password: 'abcdefgh'), isTrue);
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

  for (final (failure, message) in [
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

      expect(await submit(), isFalse);
      expect(viewModel.error, message);
      expect(viewModel.isSubmitting, isFalse);
    });
  }

  test('a new attempt clears the previous error', () async {
    repository.failure = AuthFailure.noConnection;
    await submit();
    repository.failure = null;

    await submit();

    expect(viewModel.error, isNull);
  });
}
