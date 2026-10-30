import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/data/services/location/location_service.dart';
import 'package:plantai/domain/models/listing_failure.dart';
import 'package:plantai/ui/core/widgets/photo_image.dart';
import 'package:plantai/ui/listings/view_models/nearby_view_model.dart';
import 'package:plantai/ui/listings/widgets/listings_tab_page.dart';
import 'package:plantai/ui/listings/widgets/nearby_screen.dart';

import '../../testing/fake_listing_repository.dart';
import '../../testing/fake_location_service.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakeListingRepository repository;
  late FakeLocationService location;
  late List<ListingsTab> selected;
  late List<NearbyListing> opened;
  late int donateCalls;

  setUp(() {
    repository = FakeListingRepository()
      ..nearbyListings = [costelaPerto, espadaLonge];
    location = FakeLocationService();
    selected = [];
    opened = [];
    donateCalls = 0;
  });

  Future<NearbyViewModel> pump(WidgetTester tester) async {
    final viewModel = NearbyViewModel(
      listingRepository: repository,
      locationService: location,
    )..load();
    addTearDown(viewModel.dispose);
    await pumpScreen(
      tester,
      NearbyScreen(
        viewModel: viewModel,
        onSelectTab: selected.add,
        onOpen: opened.add,
        onDonate: () => donateCalls++,
      ),
    );
    return viewModel;
  }

  testWidgets('lists the neighbors’ listings with the green distance line', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('até 30 km'), findsOneWidget);
    expect(find.text('Doações de vizinhos a até 30 km'), findsOneWidget);
    expect(find.text('Costela-de-adão'), findsOneWidget);
    expect(find.text('Monstera deliciosa · 3 mudas'), findsOneWidget);
    expect(find.text('menos de 1 km · Vila Mariana'), findsOneWidget);
    expect(find.text('Espada-de-são-jorge'), findsOneWidget);
    expect(find.text('1 muda'), findsOneWidget);
    expect(find.text('a cerca de 2 km · Saúde'), findsOneWidget);
    expect(find.byType(PhotoImage), findsNWidgets(2));
  });

  testWidgets('tapping a listing opens it', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Espada-de-são-jorge'));

    expect(opened, [espadaLonge]);
  });

  testWidgets('switches to Meus anúncios', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Meus anúncios'));

    expect(selected, [ListingsTab.mine]);
  });

  testWidgets('pulling down asks for the location and reads again', (
    tester,
  ) async {
    await pump(tester);
    repository.nearbyListings = [espadaLonge];

    await tester.fling(
      find.text('Costela-de-adão'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(location.asked, 2);
    expect(find.text('Costela-de-adão'), findsNothing);
  });

  testWidgets('scrolling to the end reads the next page', (tester) async {
    repository.nearbyListings = [
      for (var i = 0; i < 35; i++)
        NearbyListing(
          id: 'listing-$i',
          commonName: 'Muda $i',
          scientificName: null,
          photo: costelaPhoto,
          quantity: 1,
          distanceKm: i,
          neighborhood: 'Vila Mariana',
        ),
    ];
    await pump(tester);

    await tester.scrollUntilVisible(
      find.text('Muda 34'),
      500,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Muda 34'), findsOneWidget);
    expect(repository.nearbyCalls.map((call) => call.$2), [1, 2]);
  });

  testWidgets('without listings, offers "Doar a primeira"', (tester) async {
    repository.nearbyListings = [];
    await pump(tester);

    expect(find.text('Nenhuma muda a até 30 km ainda'), findsOneWidget);
    await tester.tap(find.text('Doar a primeira'));

    expect(donateCalls, 1);
  });

  testWidgets('location denied explains why, with "Tentar de novo"', (
    tester,
  ) async {
    location.next = const LocationDenied();
    await pump(tester);

    expect(find.text('Precisamos da sua localização'), findsOneWidget);
    expect(find.text('Abrir as configurações do Android'), findsNothing);
    expect(find.text('Por perto'), findsOneWidget);

    location.next = const LocationFound(vilaMariana);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Costela-de-adão'), findsOneWidget);
  });

  testWidgets('denied for good opens the Android settings', (tester) async {
    location.next = const LocationDeniedForever();
    await pump(tester);

    await tester.tap(find.text('Abrir as configurações do Android'));
    await tester.pumpAndSettle();

    expect(location.appSettingsOpened, 1);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('location off asks to turn it on', (tester) async {
    location.next = const LocationServiceDisabled();
    await pump(tester);

    expect(find.text('Ligue a localização'), findsOneWidget);
    await tester.tap(find.text('Abrir as configurações de localização'));
    await tester.pumpAndSettle();

    expect(location.locationSettingsOpened, 1);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('no connection offers "Tentar de novo"', (tester) async {
    repository.failure = ListingFailure.noConnection;
    await pump(tester);

    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );

    repository.failure = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Costela-de-adão'), findsOneWidget);
  });
}
