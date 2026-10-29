import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/ui/auth/verify_email/view_models/verify_email_view_model.dart';
import 'package:plantai/ui/auth/verify_email/widgets/verify_email_screen.dart';
import 'package:plantai/ui/core/widgets/view_model_scope.dart';

import '../../../testing/fake_auth_repository.dart';
import '../../../testing/pump_screen.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() {
    repository = FakeAuthRepository(pendingEmail: 'marina@email.com');
  });

  // The ViewModel is created inside the test, so its countdown runs on the
  // test clock, and disposed with the screen, as the router does.
  Future<void> pump(WidgetTester tester) => pumpScreen(
    tester,
    ViewModelScope(
      create: () => VerifyEmailViewModel(authRepository: repository),
      builder: (viewModel) => VerifyEmailScreen(viewModel: viewModel),
    ),
    below: const Scaffold(body: Text('Criar conta')),
  );

  Finder confirmButton() => find.widgetWithText(FilledButton, 'Confirmar');

  testWidgets('says where the code went and for how long it works', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Confirme seu e-mail'), findsOneWidget);
    expect(
      find.textContaining('marina@email.com', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('15 minutos', findRichText: true),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Código de 6 dígitos'), findsOneWidget);
  });

  testWidgets('typing the sixth digit confirms the code', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '042137');
    await tester.pumpAndSettle();

    expect(repository.calls, ['verifyEmail(042137)']);
  });

  testWidgets('keeps only digits, up to six', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '12a3456789');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '123456');
  });

  testWidgets('"Confirmar" with fewer digits shows the field error', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '123');

    await tester.tap(confirmButton());
    await tester.pumpAndSettle();

    expect(find.text('Digite os 6 dígitos do código.'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('a wrong code shows its message', (tester) async {
    repository.failure = AuthFailure.invalidCode;
    await pump(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(
      find.text('Código errado ou vencido. Confira o e-mail ou peça um novo.'),
      findsOneWidget,
    );
  });

  testWidgets('disables "Confirmar" while it checks the code', (tester) async {
    repository.gate = Completer();
    await pump(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    repository.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('counts down, then resends the code', (tester) async {
    await pump(tester);
    expect(find.text('reenvie em 0:45'), findsOneWidget);

    await tester.pump(const Duration(seconds: 45));
    await tester.tap(find.text('reenvie o código'));
    await tester.pump();

    expect(repository.calls, ['resendCode()']);
    expect(find.text('Enviamos um código novo.'), findsOneWidget);
    expect(find.text('reenvie em 0:45'), findsOneWidget);
  });

  testWidgets('"Corrigir o e-mail" goes back to Criar conta', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Corrigir o e-mail'));
    await tester.pumpAndSettle();

    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Confirme seu e-mail'), findsNothing);
  });
}
