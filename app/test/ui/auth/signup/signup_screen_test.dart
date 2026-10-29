import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/ui/auth/signup/view_models/signup_view_model.dart';
import 'package:plantai/ui/auth/signup/widgets/signup_screen.dart';

import '../../../testing/fake_auth_repository.dart';
import '../../../testing/pump_screen.dart';

void main() {
  late FakeAuthRepository repository;
  late SignupViewModel viewModel;
  late int codeSent;

  setUp(() {
    repository = FakeAuthRepository();
    viewModel = SignupViewModel(authRepository: repository);
    codeSent = 0;
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
    tester,
    SignupScreen(viewModel: viewModel, onCodeSent: () => codeSent++),
  );

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Marina Souza',
    String email = 'marina@email.com',
    String password = 'senha-boa-123',
  }) async {
    await tester.enterText(find.byType(TextField).at(0), name);
    await tester.enterText(find.byType(TextField).at(1), email);
    await tester.enterText(find.byType(TextField).at(2), password);
  }

  Finder submitButton() => find.widgetWithText(FilledButton, 'Criar conta');

  testWidgets('shows the three fields and their hints', (tester) async {
    await pump(tester);

    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(
      find.text('Nos anúncios, os vizinhos veem só o primeiro nome.'),
      findsOneWidget,
    );
    expect(find.text('Pelo menos 8 caracteres.'), findsOneWidget);
    expect(find.bySemanticsLabel('Voltar'), findsOneWidget);
  });

  testWidgets('the password is hidden', (tester) async {
    await pump(tester);

    final password = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(password.obscureText, isTrue);
  });

  testWidgets('sends the form and goes on to the code', (tester) async {
    await pump(tester);
    await fill(tester);

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(repository.calls, [
      'signUp(Marina Souza, marina@email.com, senha-boa-123)',
    ]);
    expect(codeSent, 1);
  });

  testWidgets('shows the field errors and does not call the API', (
    tester,
  ) async {
    await pump(tester);
    await fill(tester, name: '', email: 'marina', password: 'curta');

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(find.text('Informe o seu nome.'), findsOneWidget);
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(
      find.text('A senha precisa ter pelo menos 8 caracteres.'),
      findsOneWidget,
    );
    expect(repository.calls, isEmpty);
    expect(codeSent, 0);
  });

  testWidgets('disables the button and the fields while sending', (
    tester,
  ) async {
    repository.gate = Completer();
    await pump(tester);
    await fill(tester);

    await tester.tap(submitButton());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isFalse);
    }

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows the message of a failure and stays', (tester) async {
    repository.failure = AuthFailure.noConnection;
    await pump(tester);
    await fill(tester);

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );
    expect(codeSent, 0);
  });

  testWidgets('without connection, "Tentar de novo" sends it again', (
    tester,
  ) async {
    repository.failure = AuthFailure.noConnection;
    await pump(tester);
    await fill(tester);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    repository.failure = null;
    await tester.tap(find.widgetWithText(TextButton, 'Tentar de novo'));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(2));
    expect(codeSent, 1);
    expect(find.widgetWithText(TextButton, 'Tentar de novo'), findsNothing);
  });

  testWidgets('other failures offer no "Tentar de novo"', (tester) async {
    repository.failure = AuthFailure.tooManyRequests;
    await pump(tester);
    await fill(tester);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Tentar de novo'), findsNothing);
  });
}
