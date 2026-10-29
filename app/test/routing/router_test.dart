import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/main.dart';
import 'package:plantai/routing/router.dart';
import 'package:plantai/ui/core/widgets/plantai_logo.dart';

import '../testing/fake_auth_repository.dart';
import '../testing/fake_profile_repository.dart';

void main() {
  late UpdateRequired updateRequired;
  late FakeAuthRepository authRepository;
  late List<Uri> openedUrls;

  setUp(() {
    updateRequired = UpdateRequired();
    authRepository = FakeAuthRepository(signedIn: true);
    openedUrls = [];
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      PlantaiApp(
        updateRequired: updateRequired,
        authRepository: authRepository,
        profileRepository: FakeProfileRepository(),
        openUrl: (url) async {
          openedUrls.add(url);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tab(String label) => find.descendant(
    of: find.byKey(const Key('bottom-bar')),
    matching: find.text(label),
  );

  Finder cameraButton() =>
      find.bySemanticsLabel('Identificar uma planta pela foto');

  testWidgets('opens on Por perto, with the logo and "em breve"', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Mudas por perto'), findsOneWidget);
    expect(find.text('Em breve'), findsOneWidget);
    expect(find.byType(PlantaiLogo), findsOneWidget);
    expect(tab('Jardim'), findsOneWidget);
    expect(tab('Por perto'), findsOneWidget);
    expect(tab('Perfil'), findsOneWidget);
    expect(cameraButton(), findsOneWidget);
  });

  testWidgets('the tabs switch screens', (tester) async {
    await pumpApp(tester);

    await tester.tap(tab('Jardim'));
    await tester.pumpAndSettle();
    expect(find.text('Meu jardim'), findsOneWidget);
    expect(find.text('Mudas por perto'), findsNothing);

    await tester.tap(tab('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('marina@email.com'), findsOneWidget);
    expect(find.text('Meu jardim'), findsNothing);

    await tester.tap(tab('Por perto'));
    await tester.pumpAndSettle();
    expect(find.text('Mudas por perto'), findsOneWidget);
    expect(find.text('marina@email.com'), findsNothing);
  });

  testWidgets('the camera button shows "em breve" and goes back', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(cameraButton());
    await tester.pumpAndSettle();
    expect(find.text('Identificar pela foto'), findsOneWidget);
    expect(find.text('Em breve'), findsOneWidget);
    expect(find.byKey(const Key('bottom-bar')), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Mudas por perto'), findsOneWidget);
  });

  testWidgets('update required: shows "Atualize o PlantAí" with the link', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(tab('Jardim'));
    await tester.pumpAndSettle();

    updateRequired.raise();
    await tester.pumpAndSettle();

    expect(find.text('Atualize o PlantAí'), findsOneWidget);
    expect(find.byKey(const Key('bottom-bar')), findsNothing);

    const releases = 'https://github.com/angelobez/plantai/releases';
    await tester.tap(find.text(releases));
    expect(openedUrls, [Uri.parse(releases)]);
  });

  testWidgets('update required: there is no way back to the tabs', (
    tester,
  ) async {
    updateRequired.raise();
    await pumpApp(tester);

    expect(find.text('Atualize o PlantAí'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  group('without a session', () {
    setUp(() => authRepository.setSignedIn(false));

    testWidgets('opens on Login, without the tabs', (tester) async {
      await pumpApp(tester);

      expect(find.text('Entrar com e-mail'), findsOneWidget);
      expect(find.text('Entrar com Google'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsNothing);
    });

    testWidgets('any other location goes to Login', (tester) async {
      await pumpApp(tester);
      final router = GoRouter.of(
        tester.element(find.text('Entrar com e-mail')),
      );

      for (final location in [
        Routes.garden,
        Routes.profile,
        Routes.identify,
        Routes.verifyEmail,
      ]) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(
          find.text('Entrar com e-mail'),
          findsOneWidget,
          reason: location,
        );
      }
    });

    testWidgets('signing up and confirming the code opens Por perto', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('Entrar com e-mail'));
      await tester.pumpAndSettle();
      expect(find.text('Criar conta'), findsWidgets);

      await tester.enterText(find.byType(TextField).at(0), 'Marina Souza');
      await tester.enterText(find.byType(TextField).at(1), 'marina@email.com');
      await tester.enterText(find.byType(TextField).at(2), 'senha-boa-123');
      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
      await tester.pumpAndSettle();
      expect(find.text('Confirme seu e-mail'), findsOneWidget);
      expect(
        find.textContaining('marina@email.com', findRichText: true),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      expect(authRepository.calls.last, 'verifyEmail(123456)');
      expect(find.text('Mudas por perto'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsOneWidget);
    });

    testWidgets('the code screen goes back to fix the e-mail', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Entrar com e-mail'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Marina Souza');
      await tester.enterText(find.byType(TextField).at(1), 'marina@emial.com');
      await tester.enterText(find.byType(TextField).at(2), 'senha-boa-123');
      await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Corrigir o e-mail'));
      await tester.pumpAndSettle();

      expect(find.text('Criar conta'), findsWidgets);
      expect(find.text('marina@emial.com'), findsOneWidget);
    });
  });

  group('with a session', () {
    testWidgets('the entry screens go to Por perto', (tester) async {
      await pumpApp(tester);
      final router = GoRouter.of(tester.element(find.text('Mudas por perto')));

      router.go(Routes.signup);
      await tester.pumpAndSettle();

      expect(find.text('Mudas por perto'), findsOneWidget);
    });

    testWidgets('Sair in Perfil goes to Login', (tester) async {
      await pumpApp(tester);
      await tester.tap(tab('Perfil'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(authRepository.calls.last, 'signOut()');
      expect(find.text('Entrar com e-mail'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsNothing);
    });

    testWidgets('ending the session goes to Login', (tester) async {
      await pumpApp(tester);

      authRepository.setSignedIn(false);
      await tester.pumpAndSettle();

      expect(find.text('Entrar com e-mail'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsNothing);
    });
  });

  testWidgets('update required wins over the missing session', (tester) async {
    authRepository.setSignedIn(false);
    updateRequired.raise();
    await pumpApp(tester);

    expect(find.text('Atualize o PlantAí'), findsOneWidget);
  });
}
