import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/ui/auth/login/view_models/login_view_model.dart';
import 'package:plantai/ui/auth/login/widgets/login_screen.dart';
import 'package:plantai/ui/core/widgets/plantai_logo.dart';

import '../../../testing/fake_auth_repository.dart';
import '../../../testing/pump_screen.dart';

void main() {
  late FakeAuthRepository repository;
  late LoginViewModel viewModel;

  setUp(() {
    repository = FakeAuthRepository();
    viewModel = LoginViewModel(authRepository: repository);
  });

  LoginScreen login({VoidCallback? onEmail}) =>
      LoginScreen(viewModel: viewModel, onEmail: onEmail ?? () {});

  ButtonStyleButton googleButton(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.byKey(LoginScreen.googleButtonKey),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );

  testWidgets('shows the logo, the tagline and both ways in', (tester) async {
    await pumpScreen(tester, login());

    expect(find.byType(PlantaiLogo), findsOneWidget);
    expect(find.textContaining('Descubra que planta é essa'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.text('Entrar com e-mail'), findsOneWidget);
  });

  testWidgets('"Entrar com e-mail" calls onEmail', (tester) async {
    var tapped = 0;
    await pumpScreen(tester, login(onEmail: () => tapped++));

    await tester.tap(find.text('Entrar com e-mail'));

    expect(tapped, 1);
  });

  testWidgets('"Entrar com Google" signs in with Google', (tester) async {
    await pumpScreen(tester, login());

    await tester.tap(find.text('Entrar com Google'));
    await tester.pump();

    expect(repository.calls, ['signInWithGoogle()']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('both buttons are disabled while signing in', (tester) async {
    repository.gate = Completer();
    await pumpScreen(tester, login());

    await tester.tap(find.text('Entrar com Google'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(googleButton(tester).enabled, isFalse);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.ancestor(
              of: find.text('Entrar com e-mail'),
              matching: find.bySubtype<ButtonStyleButton>(),
            ),
          )
          .enabled,
      isFalse,
    );

    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(googleButton(tester).enabled, isTrue);
  });

  testWidgets('a refused link says to sign in with the password', (
    tester,
  ) async {
    repository.failure = AuthFailure.googleAccountLinkRefused;
    await pumpScreen(tester, login());

    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('Este e-mail já tem conta no PlantAí. Entre com a sua senha.'),
      findsOneWidget,
    );
  });

  testWidgets('canceling the account picker shows nothing', (tester) async {
    repository.googleCanceled = true;
    await pumpScreen(tester, login());

    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Tente de novo'), findsNothing);
  });

  testWidgets('without connection, "Tentar de novo" tries Google again', (
    tester,
  ) async {
    repository.failure = AuthFailure.noConnection;
    await pumpScreen(tester, login());
    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();

    repository.failure = null;
    await tester.tap(find.widgetWithText(TextButton, 'Tentar de novo'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['signInWithGoogle()', 'signInWithGoogle()']);
  });
}
