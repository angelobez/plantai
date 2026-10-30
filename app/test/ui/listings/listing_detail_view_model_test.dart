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

  late List<Uri> openedUrls;
  late bool opens;

  setUp(() {
    openedUrls = [];
    opens = true;
  });

  ListingDetailViewModel build({ApproximatePosition? from}) {
    final viewModel = ListingDetailViewModel(
      listingRepository: repository,
      locationService: location,
      openUrl: (url) async {
        openedUrls.add(url);
        return opens;
      },
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

  group('Tenho interesse', () {
    Future<ListingDetailViewModel> loaded() async {
      final viewModel = build(from: listPosition);
      await viewModel.load();
      return viewModel;
    }

    test('records the interest and opens the donor’s WhatsApp', () async {
      final viewModel = await loaded();
      repository.gate = Completer<void>();

      final showing = viewModel.showInterest();
      expect(viewModel.isShowingInterest, isTrue);
      repository.gate!.complete();
      await showing;

      expect(viewModel.isShowingInterest, isFalse);
      expect(repository.interests, [costelaPerto.id]);
      expect(openedUrls, [whatsappUrlOf(costelaPerto.id)]);
      expect(viewModel.interestError, isNull);
      expect(viewModel.isAvailable, isTrue);
    });

    test('tapping again opens the chat again', () async {
      final viewModel = await loaded();

      await viewModel.showInterest();
      await viewModel.showInterest();

      expect(openedUrls, hasLength(2));
    });

    test('a tap while one is on the way does nothing', () async {
      final viewModel = await loaded();
      repository.gate = Completer<void>();

      final first = viewModel.showInterest();
      await viewModel.showInterest().timeout(Duration.zero, onTimeout: () {});
      repository.gate!.complete();
      await first;

      expect(repository.interests, hasLength(1));
      expect(openedUrls, hasLength(1));
    });

    test('LISTING_NOT_ACTIVE turns the button into the notice', () async {
      final viewModel = await loaded();
      repository.interestFailure = ListingFailure.notActive;

      await viewModel.showInterest();

      expect(viewModel.isAvailable, isFalse);
      expect(viewModel.interestError, isNull);
      expect(openedUrls, isEmpty);
    });

    for (final (failure, message) in [
      (
        ListingFailure.noConnection,
        'Sem conexão com a internet. Confira a rede e tente de novo.',
      ),
      (ListingFailure.notFound, 'Esse anúncio não existe mais.'),
      (ListingFailure.ownListing, 'Esse anúncio é seu.'),
      (ListingFailure.unknown, 'Algo deu errado. Tente de novo.'),
    ]) {
      test('$failure shows "$message", keeping the button', () async {
        final viewModel = await loaded();
        repository.interestFailure = failure;

        await viewModel.showInterest();

        expect(viewModel.interestError, message);
        expect(viewModel.isAvailable, isTrue);
        expect(openedUrls, isEmpty);
      });
    }

    test('trying again clears the message', () async {
      final viewModel = await loaded();
      repository.interestFailure = ListingFailure.noConnection;
      await viewModel.showInterest();

      repository.interestFailure = null;
      await viewModel.showInterest();

      expect(viewModel.interestError, isNull);
      expect(openedUrls, [whatsappUrlOf(costelaPerto.id)]);
    });

    test('when WhatsApp cannot open, says so', () async {
      final viewModel = await loaded();
      opens = false;

      await viewModel.showInterest();

      expect(openedUrls, hasLength(1));
      expect(
        viewModel.interestError,
        'Não foi possível abrir o WhatsApp. Confira se ele está instalado.',
      );
    });
  });
}
