import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/plant.dart';
import 'package:plantai/domain/models/garden_failure.dart';
import 'package:plantai/ui/core/care_guide/care_guide_view.dart';
import 'package:plantai/ui/core/widgets/photo_image.dart';
import 'package:plantai/ui/garden/view_models/plant_view_model.dart';
import 'package:plantai/ui/garden/widgets/plant_screen.dart';

import '../../testing/fake_catalog_repository.dart';
import '../../testing/fake_garden_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakeGardenRepository gardenRepository;
  late List<Uri> openedUrls;
  late int removedCalls;

  setUp(() {
    gardenRepository = FakeGardenRepository();
    openedUrls = [];
    removedCalls = 0;
  });

  Future<PlantViewModel> pump(
    WidgetTester tester, {
    Plant? plant,
    bool settle = true,
    Future<String?> Function()? onSearchSpecies,
    Future<String?> Function()? onIdentifySpecies,
    ValueChanged<Plant>? onDonate,
  }) async {
    final viewModel = PlantViewModel(
      gardenRepository: gardenRepository,
      plantId: (plant ?? monsteraDaSala).id,
    )..load();
    addTearDown(viewModel.dispose);
    final screen = PlantScreen(
      viewModel: viewModel,
      openUrl: (url) async {
        openedUrls.add(url);
        return true;
      },
      onRemoved: () => removedCalls += 1,
      onSearchSpecies: onSearchSpecies,
      onIdentifySpecies: onIdentifySpecies,
      onDonate: onDonate,
    );
    if (settle) {
      await pumpScreen(tester, screen, below: const Text('Jardim'));
    } else {
      await tester.pumpWidget(MaterialApp(home: screen));
    }
    return viewModel;
  }

  testWidgets('shows the User photo on top, the name and the species', (
    tester,
  ) async {
    await pump(tester);

    final photo = tester.widget<PhotoImage>(find.byType(PhotoImage));
    expect(photo.photo, same(jiboiaPhoto));
    expect(find.text('Monstera da sala'), findsOneWidget);
    expect(find.text('Costela-de-adão'), findsOneWidget);
    expect(find.text('Monstera deliciosa'), findsOneWidget);
    final reference = tester.widget<ReferencePhotoImage>(
      find.byType(ReferencePhotoImage),
    );
    expect(reference.photo, same(monsteraPhoto));
    expect(
      find.text(
        'Foto de referência: Ana Autora · CC BY-SA 4.0 · commons.wikimedia.org',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  group('Doar mudas', () {
    testWidgets('gives the plant to the listing flow', (tester) async {
      final donated = <Plant>[];
      await pump(tester, onDonate: donated.add);

      final donate = find.widgetWithText(FilledButton, 'Doar mudas');
      await tester.ensureVisible(donate);
      await tester.tap(donate);

      expect(donated.single.id, monsteraDaSala.id);
    });

    testWidgets('a plant without a species can be donated too', (tester) async {
      final donated = <Plant>[];
      await pump(tester, plant: pimentaDaVo, onDonate: donated.add);

      final donate = find.widgetWithText(FilledButton, 'Doar mudas');
      await tester.ensureVisible(donate);
      await tester.tap(donate);

      expect(donated.single.id, pimentaDaVo.id);
    });

    testWidgets('does not show without the flow', (tester) async {
      await pump(tester);

      expect(find.text('Doar mudas'), findsNothing);
    });
  });

  testWidgets('shows the care rows and the full text of each one', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(CareGuideView), findsOneWidget);
    expect(find.text('1x por semana'), findsOneWidget);
    expect(find.text('Meia-sombra'), findsOneWidget);
    expect(find.text(monsteraCareGuide.propagation.details), findsOneWidget);
  });

  testWidgets('the credit opens the page of the reference photo', (
    tester,
  ) async {
    await pump(tester);
    final credit = find.textContaining(
      'Foto de referência',
      findRichText: true,
    );

    await tester.ensureVisible(credit);
    await tester.pumpAndSettle();
    await tester.tap(credit);

    expect(openedUrls, [Uri.parse(monsteraPhoto.sourceUrl)]);
  });

  testWidgets('a plant saved with only a name shows only the photo and name', (
    tester,
  ) async {
    await pump(tester, plant: pimentaDaVo);

    final photo = tester.widget<PhotoImage>(find.byType(PhotoImage));
    expect(photo.photo, same(pimentaPhoto));
    expect(find.text('Pimenta da vó'), findsOneWidget);
    expect(find.byType(ReferencePhotoImage), findsNothing);
    expect(find.byType(CareGuideView), findsNothing);
    expect(find.textContaining('Foto de referência'), findsNothing);
  });

  testWidgets('shows "gerando dicas…" while another request writes them', (
    tester,
  ) async {
    gardenRepository.generating = 1;
    await pump(tester, settle: false);
    await tester.pump();

    expect(find.text('gerando dicas…'), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('gerando dicas…'), findsNothing);
    expect(find.text('1x por semana'), findsOneWidget);
  });

  testWidgets('without connection, offers "Tentar de novo"', (tester) async {
    gardenRepository.failure = GardenFailure.noConnection;
    await pump(tester);

    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );

    gardenRepository.failure = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Monstera da sala'), findsOneWidget);
  });

  testWidgets('a plant that is not in the garden says so, without a retry', (
    tester,
  ) async {
    gardenRepository.plantsById = {};
    await pump(tester);

    expect(
      find.text('Essa planta não está mais no seu jardim.'),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('"Voltar" goes back', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Jardim'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    gardenRepository.gate = Completer<void>();
    await pump(tester, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gardenRepository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Monstera da sala'), findsOneWidget);
  });

  group('"Editar nome"', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Editar nome'));
      await tester.pumpAndSettle();
    }

    Future<void> typeAndSave(WidgetTester tester, String name) async {
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        name,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
    }

    testWidgets('renames the plant with the name typed', (tester) async {
      await pump(tester);

      await openDialog(tester);
      expect(find.text('Editar nome'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller?.text, 'Monstera da sala');
      await typeAndSave(tester, '  Jiboia da sala ');

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Jiboia da sala'), findsOneWidget);
      expect(gardenRepository.updates.single.$2.commonName, 'Jiboia da sala');
    });

    testWidgets('an empty name is refused before any call', (tester) async {
      await pump(tester);

      await openDialog(tester);
      await typeAndSave(tester, '   ');

      expect(find.text('Dê um nome para a planta.'), findsOneWidget);
      expect(gardenRepository.updates, isEmpty);
    });

    testWidgets('"Cancelar" keeps the name', (tester) async {
      await pump(tester);

      await openDialog(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Monstera da sala'), findsOneWidget);
      expect(gardenRepository.updates, isEmpty);
    });

    testWidgets('a failure says why and offers to try again', (tester) async {
      await pump(tester);
      gardenRepository.failure = GardenFailure.noConnection;

      await openDialog(tester);
      await typeAndSave(tester, 'Jiboia da sala');

      expect(
        find.text(
          'Sem conexão com a internet. Confira a rede e tente de novo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Monstera da sala'), findsOneWidget);
      gardenRepository.failure = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Jiboia da sala'), findsOneWidget);
      expect(gardenRepository.updates, hasLength(2));
    });
  });

  group('"Remover do jardim"', () {
    Future<void> tapRemove(WidgetTester tester) async {
      final button = find.widgetWithText(TextButton, 'Remover do jardim');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, then removes the plant and leaves', (
      tester,
    ) async {
      await pump(tester);

      await tapRemove(tester);
      expect(find.text('Remover do jardim?'), findsOneWidget);
      expect(gardenRepository.removed, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(gardenRepository.removed, [monsteraDaSala.id]);
      expect(removedCalls, 1);
    });

    testWidgets('"Cancelar" keeps the plant', (tester) async {
      await pump(tester);

      await tapRemove(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(gardenRepository.removed, isEmpty);
      expect(removedCalls, 0);
    });

    testWidgets('a plant without a species can be removed too', (tester) async {
      await pump(tester, plant: pimentaDaVo);

      await tapRemove(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(gardenRepository.removed, [pimentaDaVo.id]);
      expect(removedCalls, 1);
    });

    testWidgets('a failure stays on the plant and offers to try again', (
      tester,
    ) async {
      await pump(tester);
      gardenRepository.failure = GardenFailure.unknown;

      await tapRemove(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
      expect(removedCalls, 0);
      gardenRepository.failure = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(removedCalls, 1);
    });
  });

  group('"Definir espécie"', () {
    Finder button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.bySubtype<ButtonStyleButton>(),
    );

    bool isEnabled(WidgetTester tester, String label) =>
        tester.widget<ButtonStyleButton>(button(label)).enabled;

    Future<String?> choose() async => monstera.id;

    testWidgets('shows on a plant saved with only a name, with both ways', (
      tester,
    ) async {
      await pump(
        tester,
        plant: pimentaDaVo,
        onSearchSpecies: choose,
        onIdentifySpecies: choose,
      );

      expect(find.text('Definir espécie'), findsOneWidget);
      expect(
        find.textContaining('Depois de definida, a espécie não muda'),
        findsOneWidget,
      );
      expect(isEnabled(tester, 'Buscar pelo nome'), isTrue);
      expect(isEnabled(tester, 'Identificar pela foto'), isTrue);
    });

    testWidgets('does not show on a plant that has a species', (tester) async {
      await pump(tester, onSearchSpecies: choose, onIdentifySpecies: choose);

      expect(find.text('Definir espécie'), findsNothing);
      expect(find.text('Buscar pelo nome'), findsNothing);
    });

    for (final label in ['Buscar pelo nome', 'Identificar pela foto']) {
      testWidgets('"$label" sets the chosen species and shows its care guide', (
        tester,
      ) async {
        final asked = <String>[];
        await pump(
          tester,
          plant: pimentaDaVo,
          onSearchSpecies: () async {
            asked.add('search');
            return monstera.id;
          },
          onIdentifySpecies: () async {
            asked.add('identify');
            return monstera.id;
          },
        );

        await tester.tap(button(label));
        await tester.pumpAndSettle();

        expect(asked, [label == 'Buscar pelo nome' ? 'search' : 'identify']);
        expect(gardenRepository.updates.single.$2.speciesId, monstera.id);
        expect(find.text('Definir espécie'), findsNothing);
        expect(find.text('Costela-de-adão'), findsOneWidget);
        expect(find.byType(CareGuideView), findsOneWidget);
      });
    }

    testWidgets('leaving the flow without a species changes nothing', (
      tester,
    ) async {
      await pump(
        tester,
        plant: pimentaDaVo,
        onSearchSpecies: () async => null,
        onIdentifySpecies: choose,
      );

      await tester.tap(button('Buscar pelo nome'));
      await tester.pumpAndSettle();

      expect(gardenRepository.updates, isEmpty);
      expect(find.text('Definir espécie'), findsOneWidget);
    });

    testWidgets('says it is setting the species meanwhile', (tester) async {
      await pump(
        tester,
        plant: pimentaDaVo,
        onSearchSpecies: choose,
        onIdentifySpecies: choose,
      );
      gardenRepository.gate = Completer<void>();

      await tester.tap(button('Buscar pelo nome'));
      await tester.pump();

      expect(find.text('Definindo a espécie…'), findsOneWidget);
      expect(isEnabled(tester, 'Buscar pelo nome'), isFalse);
      expect(isEnabled(tester, 'Identificar pela foto'), isFalse);

      gardenRepository.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Costela-de-adão'), findsOneWidget);
    });

    testWidgets('without connection, offers "Tentar de novo"', (tester) async {
      await pump(
        tester,
        plant: pimentaDaVo,
        onSearchSpecies: choose,
        onIdentifySpecies: choose,
      );
      gardenRepository.failure = GardenFailure.noConnection;

      await tester.tap(button('Buscar pelo nome'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sem conexão com a internet. Confira a rede e tente de novo.',
        ),
        findsOneWidget,
      );
      gardenRepository.failure = null;
      await tester.ensureVisible(find.text('Tentar de novo'));
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(gardenRepository.updates, hasLength(2));
      expect(find.text('Costela-de-adão'), findsOneWidget);
    });
  });
}
