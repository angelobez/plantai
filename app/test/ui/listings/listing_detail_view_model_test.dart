import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/data/services/location/location_service.dart';
import 'package:plantai/domain/models/listing_failure.dart';
import 'package:plantai/ui/donation_profile/view_models/donation_profile_view_model.dart';
import 'package:plantai/ui/listings/view_models/listing_detail_view_model.dart';

import '../../testing/fake_listing_repository.dart';
import '../../testing/fake_location_service.dart';

void main() {
  late FakeListingRepository repository;
  late FakeLocationService location;
  final created = <ListingDetailViewModel>[];

  setUp(() {
    repository = FakeListingRepository();
    repository.details[costelaPerto.id] = detailOf(costelaPerto);
    location = FakeLocationService();
  });

  tearDown(() {
    for (final viewModel in created) {
      viewModel.dispose();
    }
    created.clear();
  });

  ListingDetailViewModel build({ApproximatePosition? from}) {
    final viewModel = ListingDetailViewModel(
      listingRepository: repository,
      locationService: location,
      listingId: costelaPerto.id,
      from: from,
    );
    created.add(viewModel);
    return viewModel;
  }

  const listPosition = ApproximatePosition(latitude: -23.6, longitude: -46.6);

  test('reads the listing from the list’s position, without asking', () async {
    final viewModel = build(from: listPosition);
    repository.gate = Completer<void>();

    final loading = viewModel.load();
    expect(viewModel.isLoading, isTrue);
    repository.gate!.complete();
    await loading;

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.listing?.donorFirstName, 'Marina');
    expect(viewModel.isAvailable, isTrue);
    expect(repository.detailCalls, [(costelaPerto.id, listPosition)]);
    expect(location.asked, 0);
  });

  test('without a position, asks for the location', () async {
    final viewModel = build();

    await viewModel.load();

    expect(location.asked, 1);
    expect(repository.detailCalls, [(costelaPerto.id, vilaMariana)]);
    expect(viewModel.listing, isNotNull);
  });

  for (final (result, problem) in [
    (const LocationDenied(), LocationProblem.denied),
    (const LocationDeniedForever(), LocationProblem.deniedForever),
    (const LocationServiceDisabled(), LocationProblem.serviceDisabled),
    (const LocationUnavailable(), LocationProblem.unavailable),
  ]) {
    test('${result.runtimeType} shows $problem', () async {
      location.next = result;
      final viewModel = build();

      await viewModel.load();

      expect(viewModel.locationProblem, problem);
      expect(viewModel.listing, isNull);
      expect(repository.detailCalls, isEmpty);
    });
  }

  test('openSettings opens the page that fixes the problem', () async {
    location.next = const LocationDeniedForever();
    final viewModel = build();
    await viewModel.load();

    await viewModel.openSettings();

    expect(location.appSettingsOpened, 1);
  });

  for (final status in [ListingStatus.donated, ListingStatus.closed]) {
    test('a $status listing shows as not available', () async {
      repository.details[costelaPerto.id] = detailOf(
        costelaPerto,
        status: status,
      );
      final viewModel = build(from: listPosition);

      await viewModel.load();

      expect(viewModel.listing, isNotNull);
      expect(viewModel.isAvailable, isFalse);
    });
  }

  test('a listing that is gone says so, with no retry', () async {
    repository.details.clear();
    final viewModel = build(from: listPosition);

    await viewModel.load();

    expect(viewModel.loadError, 'Esse anúncio não existe mais.');
    expect(viewModel.canRetry, isFalse);
  });

  test('no connection shows the message with a retry', () async {
    repository.failure = ListingFailure.noConnection;
    final viewModel = build(from: listPosition);

    await viewModel.load();

    expect(
      viewModel.loadError,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    );
    expect(viewModel.canRetry, isTrue);

    repository.failure = null;
    await viewModel.load();
    expect(viewModel.loadError, isNull);
    expect(viewModel.listing, isNotNull);
  });
}
