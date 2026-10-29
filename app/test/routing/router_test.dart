import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/photo_picker/photo_picker.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/main.dart';
import 'package:plantai/routing/router.dart';
import 'package:plantai/ui/core/widgets/plantai_logo.dart';

import '../testing/fake_auth_repository.dart';
import '../testing/fake_catalog_repository.dart';
import '../testing/fake_photo_picker.dart';
import '../testing/fake_photo_repository.dart';
import '../testing/fake_profile_repository.dart';

void main() {
  late UpdateRequired updateRequired;
  late FakeAuthRepository authRepository;
  late FakePhotoRepository photoRepository;
  late FakePhotoPicker photoPicker;
  late FakeCatalogRepository catalogRepository;
  late List<Uri> openedUrls;

  setUp(() {
    updateRequired = UpdateRequired();
    authRepository = FakeAuthRepository(signedIn: true);
    photoRepository = FakePhotoRepository();
    photoPicker = FakePhotoPicker();
    catalogRepository = FakeCatalogRepository();
    openedUrls = [];
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      PlantaiApp(
        updateRequired: updateRequired,
        authRepository: authRepository,
        profileRepository: FakeProfileRepository(),
        photoRepository: photoRepository,
        photoPicker: photoPicker,
        catalogRepository: catalogRepository,
        openUrl: (url) async {
          openedUrls.add(url);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Login → "Entrar com e-mail" → "Criar conta".
  Future<void> openSignup(WidgetTester tester) async {
    await tester.tap(find.text('Entrar com e-mail'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Criar conta', findRichText: true));
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

  group('the camera button', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(cameraButton());
      await tester.pumpAndSettle();
    }

    testWidgets('asks between camera and gallery; closing stays put', (
      tester,
    ) async {
      await pumpApp(tester);

      await openSheet(tester);
      expect(find.text('Tirar foto'), findsOneWidget);
      expect(find.text('Escolher da galeria'), findsOneWidget);
      expect(photoPicker.asked, isEmpty);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('Tirar foto'), findsNothing);
      expect(find.text('Mudas por perto'), findsOneWidget);
      expect(photoPicker.asked, isEmpty);
    });

    testWidgets('a photo from the gallery opens Foto and is sent', (
      tester,
    ) async {
      await pumpApp(tester);

      await openSheet(tester);
      await tester.tap(find.text('Escolher da galeria'));
      await tester.pumpAndSettle();

      expect(photoPicker.asked, [PhotoSource.gallery]);
      expect(find.text('Que planta é essa?'), findsOneWidget);
      expect(find.byKey(const Key('photo-preview')), findsOneWidget);
      expect(find.text('Identificar pela foto'), findsOneWidget);
      expect(find.text('Buscar pelo nome'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsNothing);
      expect(photoRepository.uploads, ['IMG_0001.jpg']);
    });

    testWidgets('"Fechar" on Foto goes back to the tab it came from', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(tab('Jardim'));
      await tester.pumpAndSettle();
      await openSheet(tester);
      await tester.tap(find.text('Tirar foto'));
      await tester.pumpAndSettle();
      expect(photoPicker.asked, [PhotoSource.camera]);

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      expect(find.text('Que planta é essa?'), findsNothing);
      expect(find.text('Meu jardim'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsOneWidget);
    });

    testWidgets('canceling the camera goes back with no error', (tester) async {
      photoPicker.next = const PickCancelled();
      await pumpApp(tester);

      await openSheet(tester);
      await tester.tap(find.text('Tirar foto'));
      await tester.pumpAndSettle();

      expect(find.text('Que planta é essa?'), findsNothing);
      expect(find.text('Mudas por perto'), findsOneWidget);
      expect(photoRepository.uploads, isEmpty);
    });

    testWidgets('a refused camera says so and still opens the gallery', (
      tester,
    ) async {
      photoPicker.next = const CameraDenied();
      await pumpApp(tester);
      await openSheet(tester);
      await tester.tap(find.text('Tirar foto'));
      await tester.pumpAndSettle();

      expect(find.textContaining('não tem acesso à câmera'), findsOneWidget);

      photoPicker.next = Picked(pickedPhoto());
      await tester.tap(find.text('Escolher da galeria'));
      await tester.pumpAndSettle();

      expect(photoPicker.asked, [PhotoSource.camera, PhotoSource.gallery]);
      expect(find.textContaining('não tem acesso à câmera'), findsNothing);
      expect(find.byKey(const Key('photo-preview')), findsOneWidget);
      expect(photoRepository.uploads, hasLength(1));
    });
  });

  group('"Buscar pelo nome"', () {
    Future<void> openSearch(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(cameraButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escolher da galeria'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buscar pelo nome'));
      await tester.pumpAndSettle();
    }

    Future<void> search(WidgetTester tester, String term) async {
      await tester.enterText(find.byType(TextField), term);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    testWidgets('opens Busca over Foto, and back keeps the same photo', (
      tester,
    ) async {
      await openSearch(tester);

      expect(find.text('Buscar espécie pelo nome'), findsOneWidget);
      expect(find.text('Que planta é essa?'), findsNothing);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Que planta é essa?'), findsOneWidget);
      expect(find.byKey(const Key('photo-preview')), findsOneWidget);
      expect(photoPicker.asked, [PhotoSource.gallery]);
      expect(photoRepository.uploads, hasLength(1));
    });

    testWidgets('a result opens the Tela da espécie, and back is Busca', (
      tester,
    ) async {
      await openSearch(tester);
      await search(tester, 'costela');

      await tester.tap(find.text('Costela-de-adão'));
      await tester.pumpAndSettle();

      expect(catalogRepository.speciesAsked, [monstera.id]);
      expect(
        find.text(
          'Monstera deliciosa · também chamada de banana-de-macaco, imbé',
        ),
        findsOneWidget,
      );

      final credit = find.textContaining(
        'Foto de referência',
        findRichText: true,
      );
      await tester.ensureVisible(credit);
      await tester.pumpAndSettle();
      await tester.tap(credit);
      expect(openedUrls, [Uri.parse(monsteraPhoto.sourceUrl)]);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Buscar espécie pelo nome'), findsOneWidget);
      expect(find.text('Costela-de-adão'), findsOneWidget);
      expect(catalogRepository.searches, ['costela']);
    });
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

      await openSignup(tester);
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
      await openSignup(tester);
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

  group('logging in with e-mail', () {
    setUp(() => authRepository.setSignedIn(false));

    Future<void> logIn(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Entrar com e-mail'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'marina@email.com');
      await tester.enterText(find.byType(TextField).at(1), 'senha-boa-123');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pumpAndSettle();
    }

    testWidgets('the right password opens Por perto', (tester) async {
      await logIn(tester);

      expect(authRepository.calls, ['logIn(marina@email.com, senha-boa-123)']);
      expect(find.text('Mudas por perto'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsOneWidget);
    });

    testWidgets(
      'an unconfirmed e-mail goes to the code, which opens Por perto',
      (tester) async {
        authRepository.failure = AuthFailure.emailNotVerified;
        await logIn(tester);

        expect(find.text('Confirme seu e-mail'), findsOneWidget);
        expect(
          find.textContaining('marina@email.com', findRichText: true),
          findsOneWidget,
        );

        authRepository.failure = null;
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pumpAndSettle();

        expect(find.text('Mudas por perto'), findsOneWidget);
      },
    );
  });

  group('forgot the password', () {
    setUp(() => authRepository.setSignedIn(false));

    testWidgets(
      '"Esqueci a senha" → e-mail → code and new password opens Por perto',
      (tester) async {
        await pumpApp(tester);
        await tester.tap(find.text('Entrar com e-mail'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Esqueci a senha'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'marina@email.com');
        await tester.tap(find.widgetWithText(FilledButton, 'Enviar código'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(0), '123456');
        await tester.enterText(find.byType(TextField).at(1), 'senha-nova-456');
        await tester.tap(find.widgetWithText(FilledButton, 'Salvar e entrar'));
        await tester.pumpAndSettle();

        expect(authRepository.calls, [
          'requestPasswordReset(marina@email.com)',
          'resetPassword(marina@email.com, 123456, senha-nova-456)',
        ]);
        expect(find.text('Mudas por perto'), findsOneWidget);
        expect(find.byKey(const Key('bottom-bar')), findsOneWidget);
      },
    );
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

    testWidgets('Perfil opens Sobre e créditos and goes back', (tester) async {
      await pumpApp(tester);
      await tester.tap(tab('Perfil'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sobre e créditos'));
      await tester.pumpAndSettle();
      expect(find.text('Pl@ntNet'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsNothing);

      await tester.tap(find.text('Pl@ntNet'));
      expect(openedUrls, [Uri.parse('https://plantnet.org/')]);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('marina@email.com'), findsOneWidget);
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
