import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/catalog_failure.dart';
import 'package:plantai/ui/catalog/view_models/species_view_model.dart';

import '../../testing/fake_catalog_repository.dart';

void main() {
  late FakeCatalogRepository catalogRepository;

  setUp(() {
    catalogRepository = FakeCatalogRepository();
  });

  SpeciesViewModel viewModelFor(String id) =>
      SpeciesViewModel(catalogRepository: catalogRepository, speciesId: id);

  test('loads the species, showing it is loading meanwhile', () async {
    catalogRepository.gate = Completer<void>();
    final viewModel = viewModelFor(monstera.id);

    final loading = viewModel.load();
    expect(viewModel.isLoading, isTrue);
    expect(viewModel.species, isNull);

    catalogRepository.gate!.complete();
    await loading;

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.species, same(monstera));
    expect(viewModel.loadError, isNull);
    expect(catalogRepository.speciesAsked, [monstera.id]);
  });

  test('no connection shows the message and offers to try again', () async {
    catalogRepository.failure = CatalogFailure.noConnection;
    final viewModel = viewModelFor(monstera.id);

    await viewModel.load();

    expect(
      viewModel.loadError,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    );
    expect(viewModel.canRetry, isTrue);

    catalogRepository.failure = null;
    await viewModel.load();

    expect(viewModel.loadError, isNull);
    expect(viewModel.species, same(monstera));
  });

  test('any other failure shows the generic message, with a retry', () async {
    catalogRepository.failure = CatalogFailure.unknown;
    final viewModel = viewModelFor(monstera.id);

    await viewModel.load();

    expect(viewModel.loadError, 'Algo deu errado. Tente de novo.');
    expect(viewModel.canRetry, isTrue);
  });

  test('a species that does not exist says so, without a retry', () async {
    final viewModel = viewModelFor('0190e0d4-0000-7000-8000-0000000000ff');

    await viewModel.load();

    expect(viewModel.loadError, 'Não achei essa espécie no Catálogo.');
    expect(viewModel.canRetry, isFalse);
  });

  test('an answer after dispose changes nothing', () async {
    catalogRepository.gate = Completer<void>();
    final viewModel = viewModelFor(monstera.id);
    final loading = viewModel.load();

    viewModel.dispose();
    catalogRepository.gate!.complete();

    await expectLater(loading, completes);
  });

  group('"gerando dicas…"', () {
    test('another request writing the guide shows "gerando dicas…" and tries again after the Retry-After', () {
      fakeAsync((async) {
        catalogRepository.generating = 1;
        final viewModel = viewModelFor(monstera.id);

        viewModel.load();
        async.flushMicrotasks();

        expect(viewModel.isGeneratingCareGuide, isTrue);
        expect(viewModel.isLoading, isTrue);
        expect(catalogRepository.speciesAsked, hasLength(1));

        async.elapse(const Duration(milliseconds: 2900));
        expect(catalogRepository.speciesAsked, hasLength(1));

        async.elapse(const Duration(milliseconds: 100));

        expect(catalogRepository.speciesAsked, hasLength(2));
        expect(viewModel.species, same(monstera));
        expect(viewModel.isGeneratingCareGuide, isFalse);
        expect(viewModel.isLoading, isFalse);
      });
    });

    test('waits for as long as the answer says', () {
      fakeAsync((async) {
        catalogRepository
          ..generating = 1
          ..retryAfter = const Duration(seconds: 5);
        final viewModel = viewModelFor(monstera.id);

        viewModel.load();
        async.elapse(const Duration(seconds: 4));
        expect(catalogRepository.speciesAsked, hasLength(1));

        async.elapse(const Duration(seconds: 1));
        expect(viewModel.species, same(monstera));
      });
    });

    test('keeps trying, then gives up with "dicas indisponíveis no momento" after 60 s', () {
      fakeAsync((async) {
        catalogRepository.generating = 1000;
        final viewModel = viewModelFor(monstera.id);

        viewModel.load();
        async.elapse(const Duration(seconds: 59));

        expect(viewModel.isGeneratingCareGuide, isTrue);
        expect(viewModel.loadError, isNull);

        async.elapse(const Duration(seconds: 1));

        // One try at 0 s and one every 3 s up to 60 s.
        expect(catalogRepository.speciesAsked, hasLength(21));
        expect(viewModel.isGeneratingCareGuide, isFalse);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.loadError, 'Dicas indisponíveis no momento.');
        expect(viewModel.canRetry, isTrue);

        async.elapse(const Duration(seconds: 30));
        expect(catalogRepository.speciesAsked, hasLength(21));

        catalogRepository.generating = 0;
        viewModel.load();
        async.flushMicrotasks();
        expect(viewModel.species, same(monstera));
        expect(viewModel.loadError, isNull);
      });
    });

    test('a slow first answer (Claude writing the guide) shows "gerando dicas…" too', () {
      fakeAsync((async) {
        catalogRepository.gate = Completer<void>();
        final viewModel = viewModelFor(monstera.id);

        viewModel.load();
        async.elapse(const Duration(milliseconds: 1900));
        expect(viewModel.isLoading, isTrue);
        expect(viewModel.isGeneratingCareGuide, isFalse);

        async.elapse(const Duration(milliseconds: 100));
        expect(viewModel.isGeneratingCareGuide, isTrue);

        catalogRepository.gate!.complete();
        async.flushMicrotasks();
        expect(viewModel.species, same(monstera));
        expect(viewModel.isGeneratingCareGuide, isFalse);
      });
    });

    test('a quick answer never shows "gerando dicas…"', () {
      fakeAsync((async) {
        final viewModel = viewModelFor(monstera.id);
        var generatingSeen = false;
        viewModel.addListener(() {
          generatingSeen |= viewModel.isGeneratingCareGuide;
        });

        viewModel.load();
        async.elapse(const Duration(seconds: 5));

        expect(viewModel.species, same(monstera));
        expect(generatingSeen, isFalse);
      });
    });

    test('stops trying once the screen is gone', () {
      fakeAsync((async) {
        catalogRepository.generating = 1000;
        final viewModel = viewModelFor(monstera.id);

        viewModel.load();
        async.flushMicrotasks();
        viewModel.dispose();
        async.elapse(const Duration(seconds: 60));

        expect(catalogRepository.speciesAsked.length, lessThanOrEqualTo(2));
      });
    });
  });
}
