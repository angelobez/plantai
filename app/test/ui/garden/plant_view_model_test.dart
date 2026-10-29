import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/plant.dart';
import 'package:plantai/domain/models/garden_failure.dart';
import 'package:plantai/ui/garden/view_models/plant_view_model.dart';

import '../../testing/fake_catalog_repository.dart';
import '../../testing/fake_garden_repository.dart';

void main() {
  late FakeGardenRepository gardenRepository;

  setUp(() {
    gardenRepository = FakeGardenRepository();
  });

  PlantViewModel viewModelFor(String id) =>
      PlantViewModel(gardenRepository: gardenRepository, plantId: id);

  test('loads the plant, showing it is loading meanwhile', () async {
    gardenRepository.gate = Completer<void>();
    final viewModel = viewModelFor(monsteraDaSala.id);

    final loading = viewModel.load();
    expect(viewModel.isLoading, isTrue);
    expect(viewModel.plant, isNull);

    gardenRepository.gate!.complete();
    await loading;

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.plant, same(monsteraDaSala));
    expect(viewModel.loadError, isNull);
    expect(gardenRepository.plantsAsked, [monsteraDaSala.id]);
  });

  test('loads a plant saved with only a name', () async {
    final viewModel = viewModelFor(pimentaDaVo.id);

    await viewModel.load();

    expect(viewModel.plant, same(pimentaDaVo));
    expect(viewModel.plant?.species, isNull);
  });

  test('no connection shows the message and offers to try again', () async {
    gardenRepository.failure = GardenFailure.noConnection;
    final viewModel = viewModelFor(monsteraDaSala.id);

    await viewModel.load();

    expect(
      viewModel.loadError,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    );
    expect(viewModel.canRetry, isTrue);

    gardenRepository.failure = null;
    await viewModel.load();

    expect(viewModel.loadError, isNull);
    expect(viewModel.plant, same(monsteraDaSala));
  });

  test('any other failure shows the generic message, with a retry', () async {
    gardenRepository.failure = GardenFailure.unknown;
    final viewModel = viewModelFor(monsteraDaSala.id);

    await viewModel.load();

    expect(viewModel.loadError, 'Algo deu errado. Tente de novo.');
    expect(viewModel.canRetry, isTrue);
  });

  test('a plant that is not in the garden says so, without a retry', () async {
    final viewModel = viewModelFor('0190e0d4-0000-7000-8000-0000000000ff');

    await viewModel.load();

    expect(viewModel.loadError, 'Essa planta não está mais no seu jardim.');
    expect(viewModel.canRetry, isFalse);
  });

  test('an answer after dispose changes nothing', () async {
    gardenRepository.gate = Completer<void>();
    final viewModel = viewModelFor(monsteraDaSala.id);
    final loading = viewModel.load();

    viewModel.dispose();
    gardenRepository.gate!.complete();

    await expectLater(loading, completes);
  });

  group('"gerando dicas…"', () {
    test('another request writing the guide shows "gerando dicas…" and tries again after the Retry-After', () {
      fakeAsync((async) {
        gardenRepository.generating = 1;
        final viewModel = viewModelFor(monsteraDaSala.id);

        viewModel.load();
        async.flushMicrotasks();

        expect(viewModel.isGeneratingCareGuide, isTrue);
        expect(viewModel.isLoading, isTrue);

        async.elapse(const Duration(milliseconds: 2900));
        expect(gardenRepository.plantsAsked, hasLength(1));

        async.elapse(const Duration(milliseconds: 100));

        expect(gardenRepository.plantsAsked, hasLength(2));
        expect(viewModel.plant, same(monsteraDaSala));
        expect(viewModel.isGeneratingCareGuide, isFalse);
        expect(viewModel.isLoading, isFalse);
      });
    });

    test('gives up with "dicas indisponíveis no momento" after 60 s', () {
      fakeAsync((async) {
        gardenRepository.generating = 1000;
        final viewModel = viewModelFor(monsteraDaSala.id);

        viewModel.load();
        async.elapse(const Duration(seconds: 59));
        expect(viewModel.isGeneratingCareGuide, isTrue);
        expect(viewModel.loadError, isNull);

        async.elapse(const Duration(seconds: 1));

        expect(gardenRepository.plantsAsked, hasLength(21));
        expect(viewModel.isGeneratingCareGuide, isFalse);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.loadError, 'Dicas indisponíveis no momento.');
        expect(viewModel.canRetry, isTrue);

        gardenRepository.generating = 0;
        viewModel.load();
        async.flushMicrotasks();
        expect(viewModel.plant, same(monsteraDaSala));
      });
    });

    test('a slow first answer shows "gerando dicas…" too', () {
      fakeAsync((async) {
        gardenRepository.gate = Completer<void>();
        final viewModel = viewModelFor(monsteraDaSala.id);

        viewModel.load();
        async.elapse(const Duration(milliseconds: 1900));
        expect(viewModel.isGeneratingCareGuide, isFalse);

        async.elapse(const Duration(milliseconds: 100));
        expect(viewModel.isGeneratingCareGuide, isTrue);

        gardenRepository.gate!.complete();
        async.flushMicrotasks();
        expect(viewModel.plant, same(monsteraDaSala));
        expect(viewModel.isGeneratingCareGuide, isFalse);
      });
    });

    test('stops trying once the screen is gone', () {
      fakeAsync((async) {
        gardenRepository.generating = 1000;
        final viewModel = viewModelFor(monsteraDaSala.id);

        viewModel.load();
        async.flushMicrotasks();
        viewModel.dispose();
        async.elapse(const Duration(seconds: 60));

        expect(gardenRepository.plantsAsked.length, lessThanOrEqualTo(2));
      });
    });
  });

  group('defineSpecies', () {
    Future<PlantViewModel> loaded(String id) async {
      final viewModel = viewModelFor(id);
      await viewModel.load();
      return viewModel;
    }

    test(
      'sets the species, then reads the plant again with its care guide',
      () async {
        final viewModel = await loaded(pimentaDaVo.id);
        gardenRepository.gate = Completer<void>();

        final defining = viewModel.defineSpecies(monstera.id);
        expect(viewModel.isDefiningSpecies, isTrue);
        expect(viewModel.plant, same(pimentaDaVo));

        gardenRepository.gate!.complete();
        await defining;

        expect(gardenRepository.updates.single.$1, pimentaDaVo.id);
        expect(gardenRepository.updates.single.$2.speciesId, monstera.id);
        expect(gardenRepository.updates.single.$2.commonName, isNull);
        expect(gardenRepository.plantsAsked, [pimentaDaVo.id, pimentaDaVo.id]);
        expect(viewModel.isDefiningSpecies, isFalse);
        expect(viewModel.plant?.species, same(monstera));
        expect(viewModel.speciesError, isNull);
      },
    );

    test('shows the loading state while it reads the plant again', () async {
      final viewModel = await loaded(pimentaDaVo.id);
      final states = <(bool, bool)>[];
      viewModel.addListener(
        () => states.add((viewModel.isLoading, viewModel.plant == null)),
      );

      await viewModel.defineSpecies(monstera.id);

      // The plant without species leaves the screen for the spinner (or
      // "gerando dicas…"), until it comes back with its guide.
      expect(states, contains((true, true)));
      expect(states.last, (false, false));
    });

    test('no connection keeps the plant, says so and tries again with the same species', () async {
      final viewModel = await loaded(pimentaDaVo.id);
      gardenRepository.failure = GardenFailure.noConnection;

      await viewModel.defineSpecies(monstera.id);

      expect(viewModel.plant, same(pimentaDaVo));
      expect(
        viewModel.speciesError,
        'Sem conexão com a internet. Confira a rede e tente de novo.',
      );
      expect(viewModel.canRetrySpecies, isTrue);
      expect(viewModel.isDefiningSpecies, isFalse);

      gardenRepository.failure = null;
      await viewModel.retryDefineSpecies();

      expect(gardenRepository.updates.map((u) => u.$2.speciesId), [
        monstera.id,
        monstera.id,
      ]);
      expect(viewModel.speciesError, isNull);
      expect(viewModel.plant?.species, same(monstera));
    });

    test(
      'a plant that got a species meanwhile shows the species it has',
      () async {
        final viewModel = await loaded(pimentaDaVo.id);
        // Set from another phone after this screen read the plant.
        gardenRepository.plantsById[pimentaDaVo.id] = Plant(
          id: pimentaDaVo.id,
          commonName: pimentaDaVo.commonName,
          photo: pimentaDaVo.photo,
          species: monstera,
        );

        await viewModel.defineSpecies(costelaDeAdao.id);

        expect(viewModel.plant?.species, same(monstera));
        expect(viewModel.speciesError, isNull);
      },
    );

    test(
      'a plant that is not in the garden says so, without a retry',
      () async {
        final viewModel = await loaded(pimentaDaVo.id);
        gardenRepository.plantsById.remove(pimentaDaVo.id);

        await viewModel.defineSpecies(monstera.id);

        expect(
          viewModel.speciesError,
          'Essa planta não está mais no seu jardim.',
        );
        expect(viewModel.canRetrySpecies, isFalse);
      },
    );

    test('any other failure shows the generic message, with a retry', () async {
      final viewModel = await loaded(pimentaDaVo.id);
      gardenRepository.failure = GardenFailure.unknown;

      await viewModel.defineSpecies(monstera.id);

      expect(viewModel.speciesError, 'Algo deu errado. Tente de novo.');
      expect(viewModel.canRetrySpecies, isTrue);
    });

    test('an answer after dispose changes nothing', () async {
      final viewModel = await loaded(pimentaDaVo.id);
      gardenRepository.gate = Completer<void>();
      final defining = viewModel.defineSpecies(monstera.id);

      viewModel.dispose();
      gardenRepository.gate!.complete();

      await expectLater(defining, completes);
      expect(gardenRepository.plantsAsked, [pimentaDaVo.id]);
    });
  });
}
