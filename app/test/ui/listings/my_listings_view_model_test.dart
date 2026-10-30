import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/listing_failure.dart';
import 'package:plantai/domain/models/new_listing.dart';
import 'package:plantai/ui/listings/view_models/my_listings_view_model.dart';

import '../../testing/fake_listing_repository.dart';

void main() {
  late FakeListingRepository repository;

  setUp(() {
    repository = FakeListingRepository(
      mine: [costelaAtiva, espadaDoada, jiboiaEncerrada],
    );
  });

  test('load shows the loading state, then the listings', () async {
    repository.gate = Completer<void>();
    final viewModel = MyListingsViewModel(listingRepository: repository);

    final loading = viewModel.load();
    expect(viewModel.isLoading, isTrue);
    expect(viewModel.listings, isNull);

    repository.gate!.complete();
    await loading;
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.listings, [costelaAtiva, espadaDoada, jiboiaEncerrada]);
    expect(viewModel.isEmpty, isFalse);
  });

  test('a User without listings sees the empty state', () async {
    repository.mine = [];
    final viewModel = MyListingsViewModel(listingRepository: repository);

    await viewModel.load();

    expect(viewModel.isEmpty, isTrue);
  });

  test('no connection offers "Tentar de novo"', () async {
    repository.failure = ListingFailure.noConnection;
    final viewModel = MyListingsViewModel(listingRepository: repository);

    await viewModel.load();

    expect(
      viewModel.loadError,
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    );
    expect(viewModel.canRetry, isTrue);

    repository.failure = null;
    await viewModel.load();
    expect(viewModel.loadError, isNull);
    expect(viewModel.listings, hasLength(3));
  });

  test('refresh keeps the list on screen while reading again', () async {
    final viewModel = MyListingsViewModel(listingRepository: repository);
    await viewModel.load();
    repository.gate = Completer<void>();

    final refreshing = viewModel.refresh();
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.listings, hasLength(3));

    repository.gate!.complete();
    await refreshing;
  });

  test('a failed refresh keeps the list and shows the error', () async {
    final viewModel = MyListingsViewModel(listingRepository: repository);
    await viewModel.load();
    repository.failure = ListingFailure.unknown;

    await viewModel.refresh();

    expect(viewModel.listings, hasLength(3));
    expect(viewModel.loadError, 'Algo deu errado. Tente de novo.');
  });

  test('a listing published reads the list again', () async {
    final viewModel = MyListingsViewModel(listingRepository: repository);
    await viewModel.load();

    await repository.create(
      const NewListing(photoId: 'photo-1', commonName: 'Jiboia', quantity: 1),
    );
    await pumpEventQueue();

    expect(viewModel.listings, hasLength(4));
    expect(viewModel.listings!.first.commonName, 'Jiboia');
  });

  test('now comes from the clock', () {
    final viewModel = MyListingsViewModel(
      listingRepository: repository,
      clock: () => DateTime.utc(2026, 10, 30, 15),
    );

    expect(viewModel.now, DateTime.utc(2026, 10, 30, 15));
  });

  test('stops listening once disposed', () async {
    final viewModel = MyListingsViewModel(listingRepository: repository);
    await viewModel.load();
    viewModel.dispose();

    await repository.create(
      const NewListing(photoId: 'photo-1', commonName: 'Jiboia', quantity: 1),
    );

    expect(repository.listed, 1);
  });
}
