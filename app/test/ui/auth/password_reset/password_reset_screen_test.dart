import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/ui/auth/password_reset/view_models/password_reset_view_model.dart';
import 'package:plantai/ui/auth/password_reset/widgets/password_reset_screen.dart';
import 'package:plantai/ui/auth/widgets/labeled_text_field.dart';
import 'package:plantai/ui/core/widgets/view_model_scope.dart';

import '../../../testing/fake_auth_repository.dart';
import '../../../testing/pump_screen.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() {
    repository = FakeAuthRepository();
  });

  // The ViewModel is created inside the test, so its countdown runs on the
  // test clock, and disposed with the screen, as the router does.
  Future<void> pump(WidgetTester tester) => pumpScreen(
    tester,
    ViewModelScope(
      create: () => PasswordResetViewModel(authRepository: repository),
      builder: (viewModel) => PasswordResetScreen(viewModel: viewModel),
    ),
    below: const Scaffold(body: Text('Entrar com e-mail')),
  );

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledTextField, label),
    matching: find.byType(TextField),
  );

  Finder button(String label) => find.widgetWithText(FilledButton, label);

  /// The hidden field behind the six boxes.
  Finder codeField() => find.byType(TextField).first;

  Future<void> goToCodeStep(WidgetTester tester) async {
    await tester.enterText(field('E-mail'), 'marina@email.com');
    await tester.tap(button('Enviar código'));
    await tester.pumpAndSettle();
    repository.calls.clear();
  }

  group('e-mail step', () {
    testWidgets('asks for the e-mail of the account', (tester) async {
      await pump(tester);

      expect(find.text('Esqueci a senha'), findsOneWidget);
      expect(field('E-mail'), findsOneWidget);
      expect(button('Enviar código'), findsOneWidget);
      expect(find.bySemanticsLabel('Código de 6 dígitos'), findsNothing);
    });

    testWidgets('an invalid e-mail shows the field error', (tester) async {
      await pump(tester);
      await tester.enterText(field('E-mail'), 'marina');

      await tester.tap(button('Enviar código'));
      await tester.pumpAndSettle();

      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      expect(repository.calls, isEmpty);
    });

    testWidgets('disables the field and the button while sending', (
      tester,
    ) async {
      await pump(tester);
      repository.gate = Completer();
      await tester.enterText(field('E-mail'), 'marina@email.com');

      await tester.tap(button('Enviar código'));
      await tester.pump();

      expect(tester.widget<TextField>(field('E-mail')).enabled, isFalse);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('an API failure shows the message and stays', (tester) async {
      await pump(tester);
      repository.failure = AuthFailure.noConnection;
      await tester.enterText(field('E-mail'), 'marina@email.com');

      await tester.tap(button('Enviar código'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sem conexão com a internet. Confira a rede e tente de novo.',
        ),
        findsOneWidget,
      );
      expect(button('Enviar código'), findsOneWidget);
    });
  });

  group('code step', () {
    testWidgets('says where the code went and asks for the new password', (
      tester,
    ) async {
      await pump(tester);
      await goToCodeStep(tester);

      expect(find.text('Crie uma senha nova'), findsOneWidget);
      expect(
        find.textContaining('marina@email.com', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('15 minutos', findRichText: true),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Código de 6 dígitos'), findsOneWidget);
      expect(field('Senha nova'), findsOneWidget);
      expect(find.text('Pelo menos 8 caracteres.'), findsOneWidget);
      expect(find.text('reenvie em 0:45'), findsOneWidget);
    });

    testWidgets('"Salvar e entrar" sets the new password', (tester) async {
      await pump(tester);
      await goToCodeStep(tester);

      await tester.enterText(codeField(), '042137');
      await tester.enterText(field('Senha nova'), 'senha-nova-456');
      await tester.tap(button('Salvar e entrar'));
      await tester.pumpAndSettle();

      expect(repository.calls, [
        'resetPassword(marina@email.com, 042137, senha-nova-456)',
      ]);
      expect(repository.isSignedIn, isTrue);
    });

    testWidgets('typing the sixth digit does not submit before the password', (
      tester,
    ) async {
      await pump(tester);
      await goToCodeStep(tester);

      await tester.enterText(codeField(), '042137');
      await tester.pumpAndSettle();

      expect(repository.calls, isEmpty);
    });

    testWidgets('shows the field errors before calling the API', (
      tester,
    ) async {
      await pump(tester);
      await goToCodeStep(tester);
      await tester.enterText(codeField(), '123');
      await tester.enterText(field('Senha nova'), 'curta');

      await tester.tap(button('Salvar e entrar'));
      await tester.pumpAndSettle();

      expect(find.text('Digite os 6 dígitos do código.'), findsOneWidget);
      expect(
        find.text('A senha precisa ter pelo menos 8 caracteres.'),
        findsOneWidget,
      );
      expect(repository.calls, isEmpty);
    });

    testWidgets('disables the fields and the buttons while saving', (
      tester,
    ) async {
      await pump(tester);
      await goToCodeStep(tester);
      repository.gate = Completer();
      await tester.enterText(codeField(), '042137');
      await tester.enterText(field('Senha nova'), 'senha-nova-456');

      await tester.tap(button('Salvar e entrar'));
      await tester.pump();

      expect(tester.widget<TextField>(field('Senha nova')).enabled, isFalse);
      expect(tester.widget<TextField>(codeField()).enabled, isFalse);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Corrigir o e-mail'),
            )
            .onPressed,
        isNull,
      );

      repository.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a wrong code shows the message', (tester) async {
      await pump(tester);
      await goToCodeStep(tester);
      repository.failure = AuthFailure.invalidCode;
      await tester.enterText(codeField(), '042137');
      await tester.enterText(field('Senha nova'), 'senha-nova-456');

      await tester.tap(button('Salvar e entrar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Código errado ou vencido. Confira o e-mail ou peça um novo.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('resends the code after the countdown', (tester) async {
      await pump(tester);
      await goToCodeStep(tester);

      await tester.pump(const Duration(seconds: 45));
      await tester.tap(find.text('reenvie o código'));
      await tester.pumpAndSettle();

      expect(repository.calls, ['requestPasswordReset(marina@email.com)']);
      expect(find.text('Enviamos um código novo.'), findsOneWidget);
    });

    testWidgets('"Corrigir o e-mail" goes back to the e-mail, kept', (
      tester,
    ) async {
      await pump(tester);
      await goToCodeStep(tester);

      await tester.tap(find.text('Corrigir o e-mail'));
      await tester.pumpAndSettle();

      expect(find.text('Esqueci a senha'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('E-mail')).controller!.text,
        'marina@email.com',
      );
    });

    testWidgets('"Voltar" goes back to the e-mail step, not out', (
      tester,
    ) async {
      await pump(tester);
      await goToCodeStep(tester);

      await tester.tap(find.bySemanticsLabel('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Esqueci a senha'), findsOneWidget);
      expect(find.text('Entrar com e-mail'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Entrar com e-mail'), findsOneWidget);
    });
  });

  testWidgets('without connection, "Tentar de novo" asks for the code again', (
    tester,
  ) async {
    repository.failure = AuthFailure.noConnection;
    await pump(tester);
    await tester.enterText(field('E-mail'), 'marina@email.com');
    await tester.tap(button('Enviar código'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );

    repository.failure = null;
    await tester.tap(find.widgetWithText(TextButton, 'Tentar de novo'));
    await tester.pumpAndSettle();

    expect(repository.calls, [
      'requestPasswordReset(marina@email.com)',
      'requestPasswordReset(marina@email.com)',
    ]);
    expect(find.bySemanticsLabel('Código de 6 dígitos'), findsOneWidget);
  });
}
