import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/listing/listing_repository.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/data/services/location/location_service.dart';
import 'package:plantai/domain/models/listing_failure.dart';
import 'package:plantai/ui/donation_profile/view_models/donation_profile_view_model.dart';
import 'package:plantai/ui/listings/view_models/nearby_view_model.dart';

import '../../testing/fake_listing_repository.dart';
import '../../testing/fake_location_service.dart';

/// [count] listings, nearest first.
List<NearbyListing> manyListings(int count) => [
  for (var i = 0; i < count; i++)
    NearbyListing(
      id: 'listing-$i',
      commonName: 'Muda $i',
      scientificName: null,
      photo: costelaPhoto,
      quantity: 1,
      distanceKm: i ~/ 3,
      neighborhood: 'Vila Mariana',
    ),
];

void main() {
  late FakeListingRepository repository;
  late FakeLocationService location;
  late NearbyViewModel viewModel;

  setUp(() {
    repository = FakeListingRepository()
      ..nearbyListings = [costelaPerto, espadaLonge];
    location = FakeLocationService();
    viewModel = NearbyViewModel(
      listingRepository: repository,
      locationService: location,
    );
  });

  tearDown(() => viewModel.dispose());

  test('load asks for the location, then lists from it', () async {
    location.gate = Completer<void>();

    final loading = viewModel.load();
    expect(viewModel.isLoading, isTrue);
    expect(viewModel.listings, isNull);
    location.gate!.complete();
    await loading;

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.listings, [costelaPerto, espadaLonge]);
    expect(viewModel.isEmpty, isFalse);
    expect(viewModel.position, vilaMariana);
    expect(viewModel.hasMore, isFalse);
    expect(location.asked, 1);
    expect(repository.nearbyCalls, [(vilaMariana, 1)]);
  });

  test('no listing within 30 km is the empty state', () async {
    repository.nearbyListings = [];

    await viewModel.load();

    expect(viewModel.isEmpty, isTrue);
  });

  test('loadMore reads the next pages while they come full', () async {
    repository.nearbyListings = manyListings(65);

    await viewModel.load();
    expect(viewModel.listings, hasLength(nearbyPageSize));
    expect(viewModel.hasMore, isTrue);

    await viewModel.loadMore();
    expect(viewModel.listings, hasLength(60));
    expect(viewModel.hasMore, isTrue);

    await viewModel.loadMore();
    expect(viewModel.listings, hasLength(65));
    expect(viewModel.hasMore, isFalse);
    expect(viewModel.listings!.last.id, 'listing-64');

    await viewModel.loadMore();
    expect(repository.nearbyCalls.map((call) => call.$2), [1, 2, 3]);
    // Without asking for the location again.
    expect(location.asked, 1);
  });

  test('loadMore runs once at a time', () async {
    repository.nearbyListings = manyListings(40);
    await viewModel.load();
    repository.gate = Completer<void>();

    final first = viewModel.loadMore();
    final second = viewModel.loadMore();
    expect(viewModel.isLoadingMore, isTrue);
    repository.gate!.complete();
    await Future.wait([first, second]);

    expect(viewModel.listings, hasLength(40));
    expect(repository.nearbyCalls, hasLength(2));
  });

  test('a failed loadMore keeps the list and can try again', () async {
    repository.nearbyListings = manyListings(31);
    await viewModel.load();
    repository.failure = ListingFailure.noConnection;

    await viewModel.loadMore();

    expect(viewModel.listings, hasLength(30));
    expect(
      viewModel.loadMoreError,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    );
    expect(viewModel.hasMore, isTrue);

    repository.failure = null;
    await viewModel.loadMore();
    expect(viewModel.listings, hasLength(31));
    expect(viewModel.loadMoreError, isNull);
  });

  test('refresh asks for the location again and reads page 1', () async {
    repository.nearbyListings = manyListings(35);
    await viewModel.load();
    await viewModel.loadMore();
    const elsewhere = ApproximatePosition(latitude: -23.6, longitude: -46.7);
    location.next = const LocationFound(elsewhere);
    repository.nearbyListings = [espadaLonge];

    await viewModel.refresh();

    expect(location.asked, 2);
    expect(repository.nearbyCalls.last, (elsewhere, 1));
    expect(viewModel.listings, [espadaLonge]);
    expect(viewModel.position, elsewhere);
    expect(viewModel.hasMore, isFalse);
  });

  for (final (result, problem) in [
    (const LocationDenied(), LocationProblem.denied),
    (const LocationDeniedForever(), LocationProblem.deniedForever),
    (const LocationServiceDisabled(), LocationProblem.serviceDisabled),
    (const LocationUnavailable(), LocationProblem.unavailable),
  ]) {
    test('${result.runtimeType} shows $problem, without a list', () async {
      location.next = result;

      await viewModel.load();

      expect(viewModel.locationProblem, problem);
      expect(viewModel.listings, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(repository.nearbyCalls, isEmpty);
    });
  }

  test('trying again after giving the permission lists', () async {
    location.next = const LocationDenied();
    await viewModel.load();
    location.next = const LocationFound(vilaMariana);

    await viewModel.load();

    expect(viewModel.locationProblem, isNull);
    expect(viewModel.listings, [costelaPerto, espadaLonge]);
  });

  test(
    'a refresh without location replaces the list with the problem',
    () async {
      await viewModel.load();
      location.next = const LocationServiceDisabled();

      await viewModel.refresh();

      expect(viewModel.locationProblem, LocationProblem.serviceDisabled);
      expect(viewModel.listings, isNull);
    },
  );

  test('openSettings opens the page that fixes the problem', () async {
    location.next = const LocationDeniedForever();
    await viewModel.load();
    await viewModel.openSettings();
    expect(location.appSettingsOpened, 1);

    location.next = const LocationServiceDisabled();
    await viewModel.load();
    await viewModel.openSettings();
    expect(location.locationSettingsOpened, 1);

    location.next = const LocationDenied();
    await viewModel.load();
    await viewModel.openSettings();
    expect(location.appSettingsOpened, 1);
    expect(location.locationSettingsOpened, 1);
  });

  test('no connection shows the message with a retry', () async {
    repository.failure = ListingFailure.noConnection;

    await viewModel.load();

    expect(
      viewModel.loadError,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    );
    expect(viewModel.canRetry, isTrue);
    expect(viewModel.listings, isNull);

    repository.failure = null;
    await viewModel.load();
    expect(viewModel.loadError, isNull);
    expect(viewModel.listings, [costelaPerto, espadaLonge]);
  });

  test('a failed refresh keeps the list with the message', () async {
    await viewModel.load();
    repository.failure = ListingFailure.unknown;

    await viewModel.refresh();

    expect(viewModel.listings, [costelaPerto, espadaLonge]);
    expect(viewModel.loadError, 'Algo deu errado. Tente de novo.');
  });

  test('an older answer that comes late is dropped', () async {
    repository.gate = Completer<void>();
    final first = viewModel.load();
    await Future<void>.delayed(Duration.zero);
    expect(repository.nearbyCalls, hasLength(1));
    location.next = const LocationDenied();
    await viewModel.load();
    repository.gate!.complete();
    await first;

    expect(viewModel.locationProblem, LocationProblem.denied);
    expect(viewModel.listings, isNull);
  });
}
