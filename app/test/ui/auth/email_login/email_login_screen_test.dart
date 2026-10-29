import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/ui/auth/email_login/view_models/email_login_view_model.dart';
import 'package:plantai/ui/auth/email_login/widgets/email_login_screen.dart';

import '../../../testing/fake_auth_repository.dart';
import '../../../testing/pump_screen.dart';

void main() {
  late FakeAuthRepository repository;
  late EmailLoginViewModel viewModel;
  late List<String> navigations;

  setUp(() {
    repository = FakeAuthRepository();
    viewModel = EmailLoginViewModel(authRepository: repository);
    navigations = [];
  });

  Future<void> pump(WidgetTester tester, {VoidCallback? onForgotPassword}) =>
      pumpScreen(
        tester,
        EmailLoginScreen(
          viewModel: viewModel,
          onVerifyEmail: () => navigations.add('verifyEmail'),
          onSignup: () => navigations.add('signup'),
          onForgotPassword: onForgotPassword,
        ),
      );

  Future<void> fill(
    WidgetTester tester, {
    String email = 'marina@email.com',
    String password = 'senha-boa-123',
  }) async {
    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), password);
  }

  Finder submitButton() => find.widgetWithText(FilledButton, 'Entrar');

  testWidgets('shows the fields and the links of the design', (tester) async {
    await pump(tester);

    expect(find.text('Entrar com e-mail'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Esqueci a senha'), findsOneWidget);
    expect(submitButton(), findsOneWidget);
    expect(
      find.textContaining('Ainda não tem conta?', findRichText: true),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Voltar'), findsOneWidget);
  });

  testWidgets('the password is hidden', (tester) async {
    await pump(tester);

    final password = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(password.obscureText, isTrue);
  });

  testWidgets('signs in with what was typed', (tester) async {
    await pump(tester);
    await fill(tester);

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(repository.calls, ['logIn(marina@email.com, senha-boa-123)']);
    expect(repository.isSignedIn, isTrue);
    expect(navigations, isEmpty);
  });

  testWidgets('shows the field errors and does not call the API', (
    tester,
  ) async {
    await pump(tester);
    await fill(tester, email: 'marina', password: '');

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Informe a sua senha.'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('wrong credentials show the generic message and stay', (
    tester,
  ) async {
    repository.failure = AuthFailure.invalidCredentials;
    await pump(tester);
    await fill(tester);

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(navigations, isEmpty);
  });

  testWidgets('an unconfirmed e-mail goes to the code screen', (tester) async {
    repository.failure = AuthFailure.emailNotVerified;
    await pump(tester);
    await fill(tester);

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(navigations, ['verifyEmail']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('disables the button, the fields and the links while sending', (
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
    for (final link in tester.widgetList<TextButton>(find.byType(TextButton))) {
      expect(link.onPressed, isNull);
    }

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('"Criar conta" calls onSignup', (tester) async {
    await pump(tester);

    await tester.tap(find.textContaining('Criar conta', findRichText: true));

    expect(navigations, ['signup']);
  });

  testWidgets('"Esqueci a senha" calls onForgotPassword', (tester) async {
    var forgot = 0;
    await pump(tester, onForgotPassword: () => forgot++);

    await tester.tap(find.text('Esqueci a senha'));

    expect(forgot, 1);
  });

  testWidgets('without connection, "Tentar de novo" logs in again', (
    tester,
  ) async {
    repository.failure = AuthFailure.noConnection;
    await pump(tester);
    await fill(tester);
    await tester.tap(submitButton());
    await tester.pumpAndSettle();
    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );

    repository.failure = AuthFailure.emailNotVerified;
    await tester.tap(find.widgetWithText(TextButton, 'Tentar de novo'));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(2));
    expect(navigations, ['verifyEmail']);
  });
}
