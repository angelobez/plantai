import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/species_summary.dart';
import 'package:plantai/domain/models/catalog_failure.dart';
import 'package:plantai/ui/catalog/view_models/search_view_model.dart';
import 'package:plantai/ui/catalog/widgets/search_screen.dart';

import '../../testing/fake_catalog_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakeCatalogRepository catalogRepository;
  late SearchViewModel viewModel;
  late List<SpeciesSummary> opened;
  late List<String> savedNames;

  setUp(() {
    catalogRepository = FakeCatalogRepository();
    viewModel = SearchViewModel(catalogRepository: catalogRepository);
    opened = [];
    savedNames = [];
  });

  Future<void> pump(WidgetTester tester, {bool canSaveNameOnly = true}) =>
      pumpScreen(
        tester,
        SearchScreen(
          viewModel: viewModel,
          onSpecies: opened.add,
          onSaveNameOnly: canSaveNameOnly ? savedNames.add : null,
        ),
        below: const Text('Foto'),
      );

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(SearchViewModel.debounce);
    await tester.pumpAndSettle();
  }

  Finder saveNameOnly(String term) =>
      find.widgetWithText(OutlinedButton, 'Salvar só com o nome “$term”');

  testWidgets('starts with the field focused and a hint', (tester) async {
    await pump(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(find.text('Buscar espécie pelo nome'), findsOneWidget);
    expect(
      find.text('Digite pelo menos 2 letras do nome popular ou científico.'),
      findsOneWidget,
    );
    expect(catalogRepository.searches, isEmpty);
  });

  testWidgets('shows the results 300 ms after typing', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'banana');
    await tester.pump(const Duration(milliseconds: 299));
    expect(catalogRepository.searches, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(catalogRepository.searches, ['banana']);
    expect(find.text('2 espécies no Catálogo'), findsOneWidget);
    expect(find.text('Costela-de-adão'), findsOneWidget);
    expect(find.text('Monstera deliciosa'), findsOneWidget);
    expect(find.text('também chamada de banana-de-macaco'), findsOneWidget);
    expect(find.text('Filodendro-ondulado'), findsOneWidget);
    expect(find.text('Thaumatophyllum bipinnatifidum'), findsOneWidget);
    expect(find.textContaining('também chamada de'), findsOneWidget);
  });

  testWidgets('counts a single result in the singular', (tester) async {
    catalogRepository.results = [filodendro];
    await pump(tester);

    await type(tester, 'filodendro');

    expect(find.text('1 espécie no Catálogo'), findsOneWidget);
  });

  testWidgets('tapping a result opens it', (tester) async {
    await pump(tester);
    await type(tester, 'costela');

    await tester.tap(find.text('Costela-de-adão'));

    expect(opened, [costelaDeAdao]);
  });

  testWidgets('below the results, offers to save with the name typed', (
    tester,
  ) async {
    await pump(tester);
    await type(tester, ' banana de macaco ');

    await tester.scrollUntilVisible(
      saveNameOnly('banana de macaco'),
      200,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Não achou?'), findsOneWidget);
    await tester.tap(saveNameOnly('banana de macaco'));

    expect(savedNames, ['banana de macaco']);
  });

  testWidgets('nothing found says so and offers to save with the name', (
    tester,
  ) async {
    catalogRepository.results = [];
    await pump(tester);

    await type(tester, 'pé de feijão');

    expect(find.text('Não achei “pé de feijão” no Catálogo'), findsOneWidget);
    expect(find.textContaining('espécies no Catálogo'), findsNothing);
    expect(saveNameOnly('pé de feijão'), findsOneWidget);
  });

  testWidgets('without saving, there is no "Salvar só com o nome"', (
    tester,
  ) async {
    catalogRepository.results = [];
    await pump(tester, canSaveNameOnly: false);

    await type(tester, 'pé de feijão');

    expect(find.text('Não achei “pé de feijão” no Catálogo'), findsOneWidget);
    expect(saveNameOnly('pé de feijão'), findsNothing);
    expect(find.textContaining('salvar só com o nome'), findsNothing);
  });

  testWidgets('shows it is searching', (tester) async {
    catalogRepository.gate = Completer<void>();
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'jiboia');
    await tester.pump(SearchViewModel.debounce);

    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    catalogRepository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('without connection, offers "Tentar de novo"', (tester) async {
    catalogRepository.failure = CatalogFailure.noConnection;
    await pump(tester);

    await type(tester, 'jiboia');

    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );
    expect(saveNameOnly('jiboia'), findsNothing);

    catalogRepository.failure = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(catalogRepository.searches, ['jiboia', 'jiboia']);
    expect(find.text('Costela-de-adão'), findsOneWidget);
  });

  testWidgets('the search key searches at once', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'jiboia');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(catalogRepository.searches, ['jiboia']);
    await tester.pump(SearchViewModel.debounce);
    await tester.pumpAndSettle();
    expect(catalogRepository.searches, ['jiboia']);
  });

  testWidgets('accepts at most 50 characters', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'a' * 60);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'a' * 50);
  });

  testWidgets('"Voltar" goes back to Foto', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Foto'), findsOneWidget);
  });
}
