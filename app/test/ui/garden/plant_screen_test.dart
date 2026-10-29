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

  setUp(() {
    gardenRepository = FakeGardenRepository();
    openedUrls = [];
  });

  Future<PlantViewModel> pump(
    WidgetTester tester, {
    Plant? plant,
    bool settle = true,
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
}
