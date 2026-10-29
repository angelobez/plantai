import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/garden_failure.dart';
import 'package:plantai/domain/models/new_plant.dart';
import 'package:plantai/ui/garden/view_models/garden_view_model.dart';

import '../../testing/fake_garden_repository.dart';

void main() {
  late FakeGardenRepository gardenRepository;

  setUp(() {
    gardenRepository = FakeGardenRepository();
  });

  GardenViewModel newViewModel() =>
      GardenViewModel(gardenRepository: gardenRepository);

  test('loads the plants, showing it is loading meanwhile', () async {
    gardenRepository.gate = Completer<void>();
    final viewModel = newViewModel();

    final loading = viewModel.load();
    expect(viewModel.isLoading, isTrue);
    expect(viewModel.plants, isNull);

    gardenRepository.gate!.complete();
    await loading;

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.plants, [monsteraDaSalaItem, pimentaDaVoItem]);
    expect(viewModel.isEmpty, isFalse);
    expect(viewModel.loadError, isNull);
  });

  test('an empty garden is empty', () async {
    gardenRepository.garden = [];
    final viewModel = newViewModel();

    await viewModel.load();

    expect(viewModel.plants, isEmpty);
    expect(viewModel.isEmpty, isTrue);
  });

  test('no connection shows the message and offers to try again', () async {
    gardenRepository.failure = GardenFailure.noConnection;
    final viewModel = newViewModel();

    await viewModel.load();

    expect(
      viewModel.loadError,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    );
    expect(viewModel.canRetry, isTrue);
    expect(viewModel.isEmpty, isFalse);

    gardenRepository.failure = null;
    await viewModel.load();

    expect(viewModel.loadError, isNull);
    expect(viewModel.plants, hasLength(2));
  });

  test('any other failure shows the generic message, with a retry', () async {
    gardenRepository.failure = GardenFailure.unknown;
    final viewModel = newViewModel();

    await viewModel.load();

    expect(viewModel.loadError, 'Algo deu errado. Tente de novo.');
    expect(viewModel.canRetry, isTrue);
  });

  test('refresh reads the list again, keeping it on screen', () async {
    final viewModel = newViewModel();
    await viewModel.load();
    gardenRepository.garden = [pimentaDaVoItem];
    gardenRepository.gate = Completer<void>();

    final refreshing = viewModel.refresh();
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.plants, hasLength(2));

    gardenRepository.gate!.complete();
    await refreshing;

    expect(viewModel.plants, [pimentaDaVoItem]);
  });

  test('a refresh that fails keeps the list and shows the message', () async {
    final viewModel = newViewModel();
    await viewModel.load();
    gardenRepository.failure = GardenFailure.noConnection;

    await viewModel.refresh();

    expect(viewModel.plants, hasLength(2));
    expect(
      viewModel.loadError,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    );
  });

  test('a plant saved elsewhere reloads the list', () async {
    final viewModel = newViewModel();
    await viewModel.load();

    await gardenRepository.create(
      const NewPlant(photoId: 'photo-1', commonName: 'Jiboia'),
    );
    await pumpEventQueue();

    expect(gardenRepository.listed, 2);
    expect(viewModel.plants?.first.commonName, 'Jiboia');
    expect(viewModel.plants, hasLength(3));
  });

  test('an older answer that comes late is dropped', () async {
    final viewModel = newViewModel();
    final firstGate = Completer<void>();
    gardenRepository.gate = firstGate;
    final first = viewModel.load();
    gardenRepository
      ..gate = null
      ..garden = [pimentaDaVoItem];
    await viewModel.refresh();

    gardenRepository.garden = [monsteraDaSalaItem];
    firstGate.complete();
    await first;

    expect(viewModel.plants, [pimentaDaVoItem]);
  });

  test('after dispose, it stops listening and changes nothing', () async {
    gardenRepository.gate = Completer<void>();
    final viewModel = newViewModel();
    final loading = viewModel.load();

    viewModel.dispose();
    gardenRepository.gate!.complete();
    await loading;
    gardenRepository.notifyListeners();
    await pumpEventQueue();

    expect(viewModel.plants, isNull);
    expect(gardenRepository.listed, 1);
  });
}
