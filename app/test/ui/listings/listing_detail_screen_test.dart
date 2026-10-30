import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/care_guide.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/data/services/location/location_service.dart';
import 'package:plantai/domain/models/listing_failure.dart';
import 'package:plantai/ui/core/widgets/photo_image.dart';
import 'package:plantai/ui/listings/view_models/listing_detail_view_model.dart';
import 'package:plantai/ui/listings/widgets/listing_detail_screen.dart';

import '../../testing/fake_listing_repository.dart';
import '../../testing/fake_location_service.dart';
import '../../testing/pump_screen.dart';

const _guide = CareGuide(
  commonName: 'Costela-de-adão',
  watering: CareTip(summary: '1x por semana', details: 'Regue com calma.'),
  light: CareTip(summary: 'Meia-sombra', details: 'Sem sol direto.'),
  propagation: CareTip(summary: 'Estaca', details: 'Corte um nó.'),
);

void main() {
  late FakeListingRepository repository;
  late FakeLocationService location;
  late int interestTaps;

  // 30/10 at noon in São Paulo: published 3 days ago.
  final now = DateTime.utc(2026, 10, 30, 15);

  setUp(() {
    repository = FakeListingRepository();
    location = FakeLocationService();
    interestTaps = 0;
  });

  Future<void> pump(WidgetTester tester, ListingDetail detail) async {
    repository.details[detail.id] = detail;
    final viewModel = ListingDetailViewModel(
      listingRepository: repository,
      locationService: location,
      listingId: detail.id,
      from: vilaMariana,
      clock: () => now,
    )..load();
    addTearDown(viewModel.dispose);
    await pumpScreen(
      tester,
      ListingDetailScreen(
        viewModel: viewModel,
        onInterest: () => interestTaps++,
      ),
      below: const Text('Por perto'),
    );
  }

  testWidgets('shows an active listing with the donor and "Tenho interesse"', (
    tester,
  ) async {
    await pump(tester, detailOf(costelaPerto));

    expect(find.byType(PhotoImage), findsOneWidget);
    expect(find.text('Costela-de-adão'), findsOneWidget);
    expect(find.text('Monstera deliciosa'), findsOneWidget);
    expect(find.text('3 mudas'), findsOneWidget);
    expect(find.text('menos de 1 km · Vila Mariana'), findsOneWidget);
    expect(find.text('Doado por Marina'), findsOneWidget);
    expect(find.text('Anunciado há 3 dias'), findsOneWidget);
    expect(find.text('“Mudas já enraizadas, pegar à tarde.”'), findsOneWidget);
    expect(
      find.text('Abre o WhatsApp de Marina com uma mensagem pronta.'),
      findsOneWidget,
    );
    expect(find.text('Este anúncio não está mais disponível'), findsNothing);

    await tester.tap(find.text('Tenho interesse'));
    expect(interestTaps, 1);
  });

  testWidgets('shows the care tips when the species has them', (tester) async {
    await pump(tester, detailOf(costelaPerto, careGuide: _guide));

    expect(find.text('Dicas de cuidado'), findsOneWidget);
    expect(find.text('1x por semana'), findsOneWidget);
    expect(find.text('Meia-sombra'), findsOneWidget);
  });

  testWidgets('without care tips or note, shows neither', (tester) async {
    await pump(tester, detailOf(espadaLonge, note: null));

    expect(find.text('Dicas de cuidado'), findsNothing);
    expect(find.textContaining('“'), findsNothing);
    expect(find.text('1 muda'), findsOneWidget);
    expect(find.text('a cerca de 2 km · Saúde'), findsOneWidget);
  });

  for (final status in [ListingStatus.donated, ListingStatus.closed]) {
    testWidgets('a $status listing says it is no longer available', (
      tester,
    ) async {
      await pump(tester, detailOf(costelaPerto, status: status));

      expect(find.text('Costela-de-adão'), findsOneWidget);
      expect(
        find.text('Este anúncio não está mais disponível'),
        findsOneWidget,
      );
      expect(find.text('Tenho interesse'), findsNothing);
    });
  }

  testWidgets('a listing that is gone says so', (tester) async {
    repository.details.clear();
    final viewModel = ListingDetailViewModel(
      listingRepository: repository,
      locationService: location,
      listingId: 'gone',
      from: vilaMariana,
    )..load();
    addTearDown(viewModel.dispose);
    await pumpScreen(tester, ListingDetailScreen(viewModel: viewModel));

    expect(find.text('Esse anúncio não existe mais.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('no connection offers "Tentar de novo"', (tester) async {
    repository.failure = ListingFailure.noConnection;
    await pump(tester, detailOf(costelaPerto));

    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );

    repository.failure = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Doado por Marina'), findsOneWidget);
  });

  testWidgets('without a position and with the location denied, explains it', (
    tester,
  ) async {
    location.next = const LocationDenied();
    repository.details[costelaPerto.id] = detailOf(costelaPerto);
    final viewModel = ListingDetailViewModel(
      listingRepository: repository,
      locationService: location,
      listingId: costelaPerto.id,
    )..load();
    addTearDown(viewModel.dispose);
    await pumpScreen(tester, ListingDetailScreen(viewModel: viewModel));

    expect(find.text('Precisamos da sua localização'), findsOneWidget);
    location.next = const LocationFound(vilaMariana);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Doado por Marina'), findsOneWidget);
  });
}
