import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/plant.dart';
import 'package:plantai/domain/models/garden_failure.dart';
import 'package:plantai/domain/models/new_plant.dart';
import 'package:plantai/ui/garden/widgets/save_plant.dart';

import '../../testing/fake_garden_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakeGardenRepository gardenRepository;
  late List<PlantSummary> saved;

  const newPlant = NewPlant(
    photoId: 'photo-1',
    commonName: 'Costela-de-adão',
    speciesId: 'species-1',
  );

  setUp(() {
    gardenRepository = FakeGardenRepository();
    saved = [];
  });

  Future<void> tapSave(WidgetTester tester) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => savePlant(
              context,
              gardenRepository: gardenRepository,
              plant: newPlant,
              onSaved: saved.add,
            ),
            child: const Text('Salvar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Salvar'));
  }

  testWidgets('saves the plant and hands it over', (tester) async {
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(gardenRepository.created.single, same(newPlant));
    expect(saved.single.commonName, 'Costela-de-adão');
  });

  testWidgets('blocks the screen while saving', (tester) async {
    gardenRepository.gate = Completer<void>();
    await tapSave(tester);
    await tester.pump();

    expect(find.text('Salvando no seu jardim…'), findsOneWidget);
    await tester.tap(find.text('Salvar'), warnIfMissed: false);
    expect(gardenRepository.created, hasLength(1));

    gardenRepository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Salvando no seu jardim…'), findsNothing);
    expect(saved, hasLength(1));
  });

  testWidgets('without connection, says so and offers "Tentar de novo"', (
    tester,
  ) async {
    gardenRepository.failure = GardenFailure.noConnection;
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );
    expect(saved, isEmpty);

    gardenRepository.failure = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(gardenRepository.created, hasLength(2));
    expect(saved, hasLength(1));
  });

  testWidgets('a photo that is gone says so, without a retry', (tester) async {
    gardenRepository.failure = GardenFailure.notFound;
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Essa foto não está mais disponível. Tire outra foto.'),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsNothing);
  });
}
