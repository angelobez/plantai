import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/photo_picker/photo_picker.dart';
import 'package:plantai/domain/models/auth_failure.dart';
import 'package:plantai/domain/models/identification_failure.dart';
import 'package:plantai/main.dart';
import 'package:plantai/routing/router.dart';
import 'package:plantai/ui/core/widgets/photo_image.dart';
import 'package:plantai/ui/core/widgets/plantai_logo.dart';

import '../testing/fake_auth_repository.dart';
import '../testing/fake_catalog_repository.dart';
import '../testing/fake_garden_repository.dart';
import '../testing/fake_identification_repository.dart';
import '../testing/fake_location_service.dart';
import '../testing/fake_photo_picker.dart';
import '../testing/fake_photo_repository.dart';
import '../testing/fake_profile_repository.dart';

void main() {
  late UpdateRequired updateRequired;
  late FakeAuthRepository authRepository;
  late FakePhotoRepository photoRepository;
  late FakePhotoPicker photoPicker;
  late FakeCatalogRepository catalogRepository;
  late FakeIdentificationRepository identificationRepository;
  late FakeGardenRepository gardenRepository;
  late FakeProfileRepository profileRepository;
  late List<Uri> openedUrls;

  setUp(() {
    updateRequired = UpdateRequired();
    authRepository = FakeAuthRepository(signedIn: true);
    photoRepository = FakePhotoRepository();
    photoPicker = FakePhotoPicker();
    catalogRepository = FakeCatalogRepository();
    identificationRepository = FakeIdentificationRepository();
    gardenRepository = FakeGardenRepository();
    profileRepository = FakeProfileRepository();
    openedUrls = [];
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      PlantaiApp(
        updateRequired: updateRequired,
        authRepository: authRepository,
        profileRepository: profileRepository,
        photoRepository: photoRepository,
        photoPicker: photoPicker,
        catalogRepository: catalogRepository,
        identificationRepository: identificationRepository,
        gardenRepository: gardenRepository,
        locationService: FakeLocationService(),
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
    expect(find.text('Monstera da sala'), findsOneWidget);
    expect(find.text('Mudas por perto'), findsNothing);

    await tester.tap(tab('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('marina@email.com'), findsOneWidget);
    expect(find.text('Monstera da sala'), findsNothing);

    await tester.tap(tab('Por perto'));
    await tester.pumpAndSettle();
    expect(find.text('Mudas por perto'), findsOneWidget);
    expect(find.text('marina@email.com'), findsNothing);
  });

  group('Meu jardim', () {
    Future<void> openGarden(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(tab('Jardim'));
      await tester.pumpAndSettle();
    }

    testWidgets('the Jardim tab lists the plants, no longer "em breve"', (
      tester,
    ) async {
      await openGarden(tester);

      expect(find.text('Em breve'), findsNothing);
      expect(find.text('2 plantas'), findsOneWidget);
      expect(find.text('Monstera da sala'), findsOneWidget);
      expect(find.text('Pimenta da vó'), findsOneWidget);
    });

    testWidgets('a plant opens its Tela da planta, and back is the list', (
      tester,
    ) async {
      await openGarden(tester);

      await tester.tap(find.text('Monstera da sala'));
      await tester.pumpAndSettle();

      expect(gardenRepository.plantsAsked, [monsteraDaSala.id]);
      expect(find.text('Monstera deliciosa'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsNothing);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('2 plantas'), findsOneWidget);
      expect(tab('Jardim'), findsOneWidget);
    });

    testWidgets('renaming a plant shows the new name back in the list', (
      tester,
    ) async {
      await openGarden(tester);
      await tester.tap(find.text('Monstera da sala'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Editar nome'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'Jiboia da sala',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Jiboia da sala'), findsOneWidget);
      expect(find.text('Monstera da sala'), findsNothing);
    });

    testWidgets('removing a plant goes back to the Jardim, without it', (
      tester,
    ) async {
      await openGarden(tester);
      await tester.tap(find.text('Pimenta da vó'));
      await tester.pumpAndSettle();

      // Below "Definir espécie", on a plant without species.
      final remove = find.widgetWithText(TextButton, 'Remover do jardim');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(tab('Jardim'), findsOneWidget);
      expect(find.text('1 planta'), findsOneWidget);
      expect(find.text('Pimenta da vó'), findsNothing);
      expect(find.text('Monstera da sala'), findsOneWidget);
    });

    testWidgets('an empty garden invites to identify, opening the camera', (
      tester,
    ) async {
      gardenRepository.garden = [];
      await openGarden(tester);

      await tester.tap(find.text('Identificar minha primeira planta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar foto'));
      await tester.pumpAndSettle();

      expect(photoPicker.asked, [PhotoSource.camera]);
      expect(find.text('Que planta é essa?'), findsOneWidget);
    });
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
      expect(find.text('2 plantas'), findsOneWidget);
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

  group('"Identificar pela foto"', () {
    Future<void> openCandidates(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(cameraButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escolher da galeria'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Identificar pela foto'));
      await tester.pumpAndSettle();
    }

    Finder button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.bySubtype<ButtonStyleButton>(),
    );

    testWidgets('identifies the photo sent and shows the candidates', (
      tester,
    ) async {
      await openCandidates(tester);

      expect(identificationRepository.identified, ['photo-1']);
      expect(find.text('Qual destas é a sua?'), findsOneWidget);
      expect(find.text('Jiboia'), findsOneWidget);
    });

    testWidgets('a candidate opens its Tela da espécie, and back is Foto', (
      tester,
    ) async {
      catalogRepository.speciesById = {jiboiaSpecies.id: monstera};
      await openCandidates(tester);

      await tester.tap(button('É esta').first);
      await tester.pumpAndSettle();

      expect(catalogRepository.speciesAsked, [jiboiaSpecies.id]);
      expect(find.text('Costela-de-adão'), findsOneWidget);

      // Candidatos left the stack: its choice is made.
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('Que planta é essa?'), findsOneWidget);
      expect(find.byKey(const Key('photo-preview')), findsOneWidget);
      expect(identificationRepository.identified, ['photo-1']);
    });

    testWidgets('"Nenhuma destas" opens Busca', (tester) async {
      await openCandidates(tester);

      await tester.tap(button('Nenhuma destas'));
      await tester.pumpAndSettle();

      expect(identificationRepository.choices, [(recognized.id, null)]);
      expect(find.text('Buscar espécie pelo nome'), findsOneWidget);
    });

    testWidgets('Foto não reconhecida: "Buscar pelo nome" opens Busca', (
      tester,
    ) async {
      identificationRepository.identification = notRecognized;
      await openCandidates(tester);
      expect(find.text('Não consegui reconhecer'), findsOneWidget);

      await tester.tap(button('Buscar pelo nome'));
      await tester.pumpAndSettle();

      expect(find.text('Buscar espécie pelo nome'), findsOneWidget);
    });

    testWidgets('Foto não reconhecida: "Tirar outra foto" picks on Foto', (
      tester,
    ) async {
      identificationRepository.identification = notRecognized;
      await openCandidates(tester);

      await tester.tap(button('Tirar outra foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tirar foto'));
      await tester.pumpAndSettle();

      expect(find.text('Que planta é essa?'), findsOneWidget);
      expect(photoPicker.asked, [PhotoSource.gallery, PhotoSource.camera]);
      expect(photoRepository.uploads, hasLength(2));
    });

    testWidgets(
      'Foto não reconhecida: "Salvar só com o nome" asks the name, saves and opens the plant',
      (tester) async {
        identificationRepository.identification = notRecognized;
        await openCandidates(tester);

        await tester.tap(button('Salvar só com o nome'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Pimenta da vó');
        await tester.tap(find.text('Salvar'));
        await tester.pumpAndSettle();

        final saved = gardenRepository.created.single;
        expect(saved.photoId, 'photo-1');
        expect(saved.commonName, 'Pimenta da vó');
        expect(saved.speciesId, isNull);
        expect(find.text('Pimenta da vó'), findsOneWidget);

        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();
        expect(find.text('3 plantas'), findsOneWidget);
      },
    );

    testWidgets('Limite diário: the search is still there', (tester) async {
      identificationRepository.failure = IdentificationFailure.dailyLimit;
      await openCandidates(tester);
      expect(find.text('A busca continua liberada'), findsOneWidget);

      await tester.tap(find.text('Buscar pelo nome'));
      await tester.pumpAndSettle();

      expect(find.text('Buscar espécie pelo nome'), findsOneWidget);
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

    testWidgets(
      '"Salvar no meu jardim" saves the species with the photo, and back is the Jardim tab',
      (tester) async {
        await openSearch(tester);
        await search(tester, 'costela');
        await tester.tap(find.text('Costela-de-adão'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Salvar no meu jardim'));
        await tester.pumpAndSettle();

        final saved = gardenRepository.created.single;
        expect(saved.photoId, 'photo-1');
        expect(saved.commonName, 'Costela-de-adão');
        expect(saved.speciesId, monstera.id);
        // The Tela da planta, with the species and its guide.
        expect(gardenRepository.plantsAsked, ['plant-1']);
        expect(find.text('Monstera deliciosa'), findsOneWidget);
        expect(find.text('Salvar no meu jardim'), findsNothing);

        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();

        expect(tab('Jardim'), findsOneWidget);
        expect(find.text('3 plantas'), findsOneWidget);
        expect(find.text('Que planta é essa?'), findsNothing);
      },
    );

    testWidgets('"Salvar só com o nome" saves the term and opens the plant', (
      tester,
    ) async {
      catalogRepository.results = [];
      await openSearch(tester);
      await search(tester, 'pimenta da vó');

      await tester.tap(find.text('Salvar só com o nome “pimenta da vó”'));
      await tester.pumpAndSettle();

      final saved = gardenRepository.created.single;
      expect(saved.commonName, 'pimenta da vó');
      expect(saved.speciesId, isNull);
      expect(find.text('pimenta da vó'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('"Definir espécie"', () {
    Finder button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.bySubtype<ButtonStyleButton>(),
    );

    /// Jardim → the plant saved with only a name.
    Future<void> openPlant(WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(tab('Jardim'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pimenta da vó'));
      await tester.pumpAndSettle();
      expect(find.text('Definir espécie'), findsOneWidget);
    }

    Future<void> tapInView(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> searchAndChoose(WidgetTester tester) async {
      expect(find.text('Buscar espécie pelo nome'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'costela');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.textContaining('Salvar só com o nome'), findsNothing);
      await tester.tap(find.text('Costela-de-adão'));
      await tester.pumpAndSettle();
    }

    /// Back on the Tela da planta, which now has the species and its guide,
    /// with the plant's own photo; the new photo, if any, was never saved.
    void expectSpeciesSet(String speciesId) {
      final update = gardenRepository.updates.single;
      expect(update.$1, pimentaDaVo.id);
      expect(update.$2.speciesId, speciesId);
      expect(gardenRepository.created, isEmpty);
      expect(find.text('Pimenta da vó'), findsOneWidget);
      expect(find.text('Monstera deliciosa'), findsOneWidget);
      expect(find.text('Definir espécie'), findsNothing);
      expect(find.text('Que planta é essa?'), findsNothing);
      expect(find.text('Buscar espécie pelo nome'), findsNothing);
    }

    Future<void> openPhoto(WidgetTester tester) async {
      await tapInView(tester, button('Identificar pela foto'));
      await tester.tap(find.text('Escolher da galeria'));
      await tester.pumpAndSettle();
      expect(find.text('Que planta é essa?'), findsOneWidget);
    }

    testWidgets('"Buscar pelo nome" sets the species chosen in Busca', (
      tester,
    ) async {
      await openPlant(tester);

      await tapInView(tester, button('Buscar pelo nome'));
      await searchAndChoose(tester);

      expectSpeciesSet(monstera.id);
      expect(catalogRepository.speciesAsked, isEmpty);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('2 plantas'), findsOneWidget);
    });

    testWidgets('leaving Busca without a species changes nothing', (
      tester,
    ) async {
      await openPlant(tester);

      await tapInView(tester, button('Buscar pelo nome'));
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(gardenRepository.updates, isEmpty);
      expect(find.text('Definir espécie'), findsOneWidget);
    });

    testWidgets(
      '"Identificar pela foto" identifies a new photo and sets the chosen candidate',
      (tester) async {
        await openPlant(tester);

        await openPhoto(tester);
        await tester.tap(find.text('Identificar pela foto'));
        await tester.pumpAndSettle();
        await tester.tap(button('É esta').first);
        await tester.pumpAndSettle();

        expect(identificationRepository.identified, ['photo-1']);
        expect(identificationRepository.choices, [(recognized.id, 0)]);
        expectSpeciesSet(jiboiaSpecies.id);
        final photo = tester.widget<PhotoImage>(find.byType(PhotoImage));
        expect(photo.photo, same(pimentaPhoto));
      },
    );

    testWidgets('closing Foto changes nothing', (tester) async {
      await openPlant(tester);

      await openPhoto(tester);
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      expect(gardenRepository.updates, isEmpty);
      expect(find.text('Definir espécie'), findsOneWidget);
    });

    testWidgets('"Buscar pelo nome" on Foto sets the species too', (
      tester,
    ) async {
      await openPlant(tester);

      await openPhoto(tester);
      await tester.tap(find.text('Buscar pelo nome'));
      await tester.pumpAndSettle();
      await searchAndChoose(tester);

      expectSpeciesSet(monstera.id);
    });

    testWidgets('"Nenhuma destas" opens Busca, and back is Foto', (
      tester,
    ) async {
      await openPlant(tester);
      await openPhoto(tester);
      await tester.tap(find.text('Identificar pela foto'));
      await tester.pumpAndSettle();

      await tester.tap(button('Nenhuma destas'));
      await tester.pumpAndSettle();
      expect(identificationRepository.choices, [(recognized.id, null)]);
      expect(find.text('Buscar espécie pelo nome'), findsOneWidget);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('Que planta é essa?'), findsOneWidget);
      expect(gardenRepository.updates, isEmpty);
    });

    testWidgets('"Nenhuma destas", then a result, sets the species', (
      tester,
    ) async {
      await openPlant(tester);
      await openPhoto(tester);
      await tester.tap(find.text('Identificar pela foto'));
      await tester.pumpAndSettle();

      await tester.tap(button('Nenhuma destas'));
      await tester.pumpAndSettle();
      await searchAndChoose(tester);

      expectSpeciesSet(monstera.id);
    });

    testWidgets(
      'Foto não reconhecida has no "Salvar só com o nome", and its search sets the species',
      (tester) async {
        identificationRepository.identification = notRecognized;
        await openPlant(tester);
        await openPhoto(tester);
        await tester.tap(find.text('Identificar pela foto'));
        await tester.pumpAndSettle();
        expect(find.text('Não consegui reconhecer'), findsOneWidget);
        expect(find.text('Salvar só com o nome'), findsNothing);

        await tester.tap(button('Buscar pelo nome'));
        await tester.pumpAndSettle();
        await searchAndChoose(tester);

        expectSpeciesSet(monstera.id);
      },
    );
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

  group('Perfil de doação', () {
    testWidgets('the Perfil opens it, saves and shows the phone and the '
        'neighborhood', (tester) async {
      await pumpApp(tester);
      await tester.tap(tab('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Não informado'), findsNWidgets(2));

      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil de doação'), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsNothing);

      await tester.enterText(find.byType(TextField).first, '11987654321');
      await tester.tap(find.text('Usar minha localização'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Perfil de doação'), findsNothing);
      expect(find.text('(11) 98765-4321'), findsOneWidget);
      expect(find.text('Vila Mariana'), findsOneWidget);
      expect(find.text('Não informado'), findsNothing);
      expect(
        profileRepository.donationProfiles.single.phone,
        '(11) 98765-4321',
      );
    });

    testWidgets('back returns to the Perfil without saving', (tester) async {
      await pumpApp(tester);
      await tester.tap(tab('Perfil'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Localização de doação'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.text('marina@email.com'), findsOneWidget);
      expect(find.text('Não informado'), findsNWidgets(2));
      expect(profileRepository.donationProfiles, isEmpty);
    });
  });
}
