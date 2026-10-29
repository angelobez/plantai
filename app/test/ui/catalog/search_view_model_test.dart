import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/catalog_failure.dart';
import 'package:plantai/ui/catalog/view_models/search_view_model.dart';

import '../../testing/fake_catalog_repository.dart';

void main() {
  late FakeCatalogRepository catalogRepository;
  late SearchViewModel viewModel;

  setUp(() {
    catalogRepository = FakeCatalogRepository();
    viewModel = SearchViewModel(catalogRepository: catalogRepository);
  });

  group('debounce', () {
    test('searches 300 ms after the last change, once', () {
      fakeAsync((async) {
        viewModel.onQueryChanged('co');
        async.elapse(const Duration(milliseconds: 200));
        viewModel.onQueryChanged('cos');
        async.elapse(const Duration(milliseconds: 200));
        viewModel.onQueryChanged('costela');
        async.elapse(const Duration(milliseconds: 299));

        expect(catalogRepository.searches, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        expect(catalogRepository.searches, ['costela']);

        async.flushMicrotasks();
        expect(viewModel.results, [costelaDeAdao, filodendro]);
        expect(viewModel.searchedTerm, 'costela');
      });
    });

    test('searches the term without the spaces around it', () {
      fakeAsync((async) {
        viewModel.onQueryChanged('  costela ');
        async.elapse(SearchViewModel.debounce);

        expect(catalogRepository.searches, ['costela']);
      });
    });

    test('does not search again when only the spaces changed', () {
      fakeAsync((async) {
        viewModel.onQueryChanged('costela');
        async.elapse(SearchViewModel.debounce);
        viewModel.onQueryChanged('costela ');
        async.elapse(SearchViewModel.debounce);

        expect(catalogRepository.searches, ['costela']);
      });
    });

    test('a term shorter than 2 characters clears the results, unsearched', () {
      fakeAsync((async) {
        viewModel.onQueryChanged('costela');
        async.elapse(SearchViewModel.debounce);
        expect(viewModel.results, isNotEmpty);

        viewModel.onQueryChanged(' c ');
        async.elapse(SearchViewModel.debounce);

        expect(catalogRepository.searches, ['costela']);
        expect(viewModel.results, isNull);
        expect(viewModel.isTermTooShort, isTrue);
      });
    });

    test('a late answer for an older term is ignored', () {
      fakeAsync((async) {
        catalogRepository.gate = Completer<void>();
        viewModel.onQueryChanged('costela');
        async.elapse(SearchViewModel.debounce);
        expect(viewModel.isSearching, isTrue);

        viewModel.onQueryChanged('c');
        catalogRepository.gate!.complete();
        async.flushMicrotasks();

        expect(viewModel.results, isNull);
        expect(viewModel.isSearching, isFalse);
      });
    });

    test('searching now drops the search still waiting', () {
      fakeAsync((async) {
        viewModel.onQueryChanged('jiboia');
        viewModel.searchNow('jiboia');
        async.elapse(SearchViewModel.debounce);

        expect(catalogRepository.searches, ['jiboia']);
      });
    });

    test('nothing is searched after dispose', () {
      fakeAsync((async) {
        viewModel.onQueryChanged('costela');
        viewModel.dispose();
        async.elapse(SearchViewModel.debounce);

        expect(catalogRepository.searches, isEmpty);
      });
    });
  });

  test('shows it is searching until the results arrive', () async {
    catalogRepository.gate = Completer<void>();
    final notified = <bool>[];
    viewModel.addListener(() => notified.add(viewModel.isSearching));

    final searching = viewModel.searchNow('jiboia');
    expect(viewModel.isSearching, isTrue);

    catalogRepository.gate!.complete();
    await searching;

    expect(viewModel.isSearching, isFalse);
    expect(notified, [true, false]);
  });

  test(
    'nothing found leaves an empty list, so the screen offers the name',
    () async {
      catalogRepository.results = [];

      await viewModel.searchNow('banana de macaco');

      expect(viewModel.results, isEmpty);
      expect(viewModel.nothingFound, isTrue);
      expect(viewModel.searchedTerm, 'banana de macaco');
    },
  );

  test('no connection shows the message and offers to try again', () async {
    catalogRepository.failure = CatalogFailure.noConnection;

    await viewModel.searchNow('jiboia');

    expect(
      viewModel.error,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    );
    expect(viewModel.canRetry, isTrue);
    expect(viewModel.results, isNull);
    expect(viewModel.nothingFound, isFalse);

    catalogRepository.failure = null;
    await viewModel.retry();

    expect(catalogRepository.searches, ['jiboia', 'jiboia']);
    expect(viewModel.error, isNull);
    expect(viewModel.results, [costelaDeAdao, filodendro]);
  });

  test('any other failure shows the generic message, with a retry', () async {
    catalogRepository.failure = CatalogFailure.unknown;

    await viewModel.searchNow('jiboia');

    expect(viewModel.error, 'Algo deu errado. Tente de novo.');
    expect(viewModel.canRetry, isTrue);
  });

  test('a new term clears the last error', () {
    fakeAsync((async) {
      catalogRepository.failure = CatalogFailure.noConnection;
      viewModel.onQueryChanged('jiboia');
      async.elapse(SearchViewModel.debounce);
      expect(viewModel.error, isNotNull);

      viewModel.onQueryChanged('j');

      expect(viewModel.error, isNull);
    });
  });
}
