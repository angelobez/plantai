import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/plant.dart';
import 'package:plantai/domain/models/garden_failure.dart';
import 'package:plantai/ui/core/widgets/photo_image.dart';
import 'package:plantai/ui/garden/view_models/garden_view_model.dart';
import 'package:plantai/ui/garden/widgets/garden_screen.dart';

import '../../testing/fake_garden_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakeGardenRepository gardenRepository;
  late List<PlantSummary> opened;
  late int identifyTaps;

  setUp(() {
    gardenRepository = FakeGardenRepository();
    opened = [];
    identifyTaps = 0;
  });

  Future<GardenViewModel> pump(WidgetTester tester) async {
    final viewModel = GardenViewModel(gardenRepository: gardenRepository)
      ..load();
    addTearDown(viewModel.dispose);
    await pumpScreen(
      tester,
      GardenScreen(
        viewModel: viewModel,
        onPlant: opened.add,
        onIdentify: () => identifyTaps += 1,
      ),
    );
    return viewModel;
  }

  testWidgets('lists the plants with photo, name, species and watering', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('2 plantas'), findsOneWidget);
    expect(find.text('Monstera da sala'), findsOneWidget);
    expect(find.text('Costela-de-adão'), findsOneWidget);
    expect(find.text('Rega · 1x por semana'), findsOneWidget);
    expect(find.text('Pimenta da vó'), findsOneWidget);
    expect(find.text('Sem espécie'), findsOneWidget);
    expect(find.text('Sem dicas: defina a espécie'), findsOneWidget);
    final photos = tester
        .widgetList<PhotoImage>(find.byType(PhotoImage))
        .map((image) => image.photo.id);
    expect(photos, [jiboiaPhoto.id, pimentaPhoto.id]);
  });

  testWidgets('says "1 planta" for a single plant', (tester) async {
    gardenRepository.garden = [pimentaDaVoItem];

    await pump(tester);

    expect(find.text('1 planta'), findsOneWidget);
  });

  testWidgets('a species without a written guide shows no watering line', (
    tester,
  ) async {
    gardenRepository.garden = [
      PlantSummary(
        id: 'plant-x',
        commonName: 'Nova',
        photo: jiboiaPhoto,
        species: const PlantSpeciesSummary(
          id: 'species-x',
          commonName: 'Jiboia',
          scientificName: 'Epipremnum aureum',
        ),
      ),
    ];

    await pump(tester);

    expect(find.text('Jiboia'), findsOneWidget);
    expect(find.textContaining('Rega'), findsNothing);
    expect(find.textContaining('Sem dicas'), findsNothing);
  });

  testWidgets('tapping a card opens the plant', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Pimenta da vó'));

    expect(opened, [pimentaDaVoItem]);
  });

  testWidgets('pulling the list down reads it again', (tester) async {
    await pump(tester);
    gardenRepository.garden = [pimentaDaVoItem];

    await tester.fling(
      find.text('Monstera da sala'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(gardenRepository.listed, 2);
    expect(find.text('Monstera da sala'), findsNothing);
    expect(find.text('1 planta'), findsOneWidget);
  });

  testWidgets('an empty garden invites to identify the first plant', (
    tester,
  ) async {
    gardenRepository.garden = [];

    await pump(tester);

    expect(find.text('Seu jardim está vazio'), findsOneWidget);
    expect(
      find.text(
        'Tire uma foto de uma planta sua para descobrir a espécie e receber '
        'dicas de cuidado.',
      ),
      findsOneWidget,
    );
    expect(find.text('0 plantas'), findsNothing);

    await tester.tap(find.text('Identificar minha primeira planta'));

    expect(identifyTaps, 1);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    gardenRepository.gate = Completer<void>();
    final viewModel = GardenViewModel(gardenRepository: gardenRepository)
      ..load();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: GardenScreen(
          viewModel: viewModel,
          onPlant: opened.add,
          onIdentify: () {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gardenRepository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Monstera da sala'), findsOneWidget);
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

  testWidgets('a refresh that fails keeps the list, with the message', (
    tester,
  ) async {
    final viewModel = await pump(tester);
    gardenRepository.failure = GardenFailure.noConnection;

    await viewModel.refresh();
    await tester.pumpAndSettle();

    expect(find.text('Monstera da sala'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
