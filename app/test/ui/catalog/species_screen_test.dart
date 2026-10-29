import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/species.dart';
import 'package:plantai/domain/models/catalog_failure.dart';
import 'package:plantai/ui/catalog/view_models/species_view_model.dart';
import 'package:plantai/ui/catalog/widgets/species_screen.dart';
import 'package:plantai/ui/core/widgets/photo_image.dart';

import '../../testing/fake_catalog_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakeCatalogRepository catalogRepository;
  late List<Uri> openedUrls;

  setUp(() {
    catalogRepository = FakeCatalogRepository();
    openedUrls = [];
  });

  Future<SpeciesViewModel> pump(
    WidgetTester tester, {
    String id = '0190e0d4-0000-7000-8000-0000000000c1',
    bool settle = true,
  }) async {
    final viewModel = SpeciesViewModel(
      catalogRepository: catalogRepository,
      speciesId: id,
    )..load();
    final screen = SpeciesScreen(
      viewModel: viewModel,
      openUrl: (url) async {
        openedUrls.add(url);
        return true;
      },
    );
    if (settle) {
      await pumpScreen(tester, screen, below: const Text('Busca'));
    } else {
      await tester.pumpWidget(MaterialApp(home: screen));
    }
    return viewModel;
  }

  testWidgets('shows the reference photo, the names and the credit', (
    tester,
  ) async {
    await pump(tester);

    final photo = tester.widget<ReferencePhotoImage>(
      find.byType(ReferencePhotoImage),
    );
    expect(photo.photo, same(monsteraPhoto));
    expect(find.text('Costela-de-adão'), findsOneWidget);
    expect(
      find.text(
        'Monstera deliciosa · também chamada de banana-de-macaco, imbé',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Foto de referência: Ana Autora · CC BY-SA 4.0 · commons.wikimedia.org',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('without other names, shows only the scientific one', (
    tester,
  ) async {
    const calathea = Species(
      id: '0190e0d4-0000-7000-8000-0000000000c3',
      commonName: 'Calathea orbifolia',
      scientificName: 'Calathea orbifolia',
      referencePhoto: monsteraPhoto,
    );
    catalogRepository.speciesById = {calathea.id: calathea};

    await pump(tester, id: calathea.id);

    expect(find.text('Calathea orbifolia'), findsNWidgets(2));
    expect(find.textContaining('também chamada'), findsNothing);
  });

  testWidgets('the credit opens the page of the photo', (tester) async {
    await pump(tester);

    await tester.tap(
      find.textContaining('Foto de referência', findRichText: true),
    );

    expect(openedUrls, [Uri.parse(monsteraPhoto.sourceUrl)]);
  });

  testWidgets('shows it is loading', (tester) async {
    catalogRepository.gate = Completer<void>();
    await pump(tester, settle: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsOneWidget);

    catalogRepository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Costela-de-adão'), findsOneWidget);
  });

  testWidgets('without connection, offers "Tentar de novo"', (tester) async {
    catalogRepository.failure = CatalogFailure.noConnection;
    await pump(tester);

    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );

    catalogRepository.failure = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(catalogRepository.speciesAsked, hasLength(2));
    expect(find.text('Costela-de-adão'), findsOneWidget);
  });

  testWidgets('a species that does not exist says so, without a retry', (
    tester,
  ) async {
    await pump(tester, id: '0190e0d4-0000-7000-8000-0000000000ff');

    expect(find.text('Não achei essa espécie no Catálogo.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('"Voltar" goes back', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Busca'), findsOneWidget);
  });
}
