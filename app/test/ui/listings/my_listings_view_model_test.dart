import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/domain/models/listing_changes.dart';
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

  group("the donor's actions", () {
    Future<MyListingsViewModel> loaded() async {
      final viewModel = MyListingsViewModel(listingRepository: repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();
      return viewModel;
    }

    MyListing costelaIn(MyListingsViewModel viewModel) =>
        viewModel.listings!.firstWhere((item) => item.id == costelaAtiva.id);

    test('edit sends the changes and the list reads them again', () async {
      final viewModel = await loaded();

      final edited = await viewModel.edit(
        costelaAtiva,
        const ListingChanges(quantity: 5, note: ''),
      );
      await pumpEventQueue();

      expect(edited, isTrue);
      expect(repository.updates.single.$1, costelaAtiva.id);
      expect(repository.updates.single.$2.quantity, 5);
      expect(costelaIn(viewModel).quantity, 5);
      expect(costelaIn(viewModel).note, isNull);
      expect(viewModel.actionError, isNull);
    });

    test('close closes the listing and the list shows it closed', () async {
      final viewModel = await loaded();

      final closed = await viewModel.close(costelaAtiva);
      await pumpEventQueue();

      expect(closed, isTrue);
      expect(repository.closed, [costelaAtiva.id]);
      expect(costelaIn(viewModel).status, ListingStatus.closed);
    });

    test(
      'donate takes the seedlings off and the list reads them again',
      () async {
        final viewModel = await loaded();

        final donated = await viewModel.donate(costelaAtiva, 2);
        await pumpEventQueue();

        expect(donated, isTrue);
        expect(repository.donations, [(costelaAtiva.id, 2)]);
        expect(costelaIn(viewModel).quantity, 1);
        expect(costelaIn(viewModel).status, ListingStatus.active);
      },
    );

    test('donating every seedling left shows the listing donated', () async {
      final viewModel = await loaded();

      await viewModel.donate(costelaAtiva, costelaAtiva.quantity);
      await pumpEventQueue();

      expect(costelaIn(viewModel).quantity, 0);
      expect(costelaIn(viewModel).status, ListingStatus.donated);
      expect(costelaIn(viewModel).canRenew, isFalse);
    });

    test('renew renews the listing and the list reads it again', () async {
      final viewModel = await loaded();

      final renewed = await viewModel.renew(costelaAtiva);
      await pumpEventQueue();

      expect(renewed, isTrue);
      expect(repository.renewed, [costelaAtiva.id]);
      expect(costelaIn(viewModel).canRenew, isFalse);
      expect(
        costelaIn(viewModel).expiresAt.isAfter(costelaAtiva.expiresAt),
        isTrue,
      );
    });

    test(
      'more seedlings than the listing has says so and reads the list again',
      () async {
        final viewModel = await loaded();
        repository.actionFailure = ListingFailure.invalidDonationCount;
        final listedBefore = repository.listed;

        final donated = await viewModel.donate(costelaAtiva, 3);
        await pumpEventQueue();

        expect(donated, isFalse);
        expect(
          viewModel.actionError,
          'O anúncio tem menos mudas do que isso agora.',
        );
        expect(repository.listed, listedBefore + 1);
      },
    );

    test('renewing too early says so and reads the list again', () async {
      final viewModel = await loaded();
      repository.actionFailure = ListingFailure.renewalNotAllowed;
      final listedBefore = repository.listed;

      final renewed = await viewModel.renew(costelaAtiva);
      await pumpEventQueue();

      expect(renewed, isFalse);
      expect(
        viewModel.actionError,
        'Só dá para renovar nos últimos 7 dias antes de expirar.',
      );
      expect(repository.listed, listedBefore + 1);
    });

    test('isActing is true while an action runs', () async {
      final viewModel = await loaded();
      repository.gate = Completer<void>();

      final closing = viewModel.close(costelaAtiva);
      expect(viewModel.isActing, isTrue);

      repository.gate!.complete();
      await closing;
      expect(viewModel.isActing, isFalse);
    });

    test('without connection, the action fails with the message and the '
        'list stays', () async {
      final viewModel = await loaded();
      repository.actionFailure = ListingFailure.noConnection;

      final closed = await viewModel.close(costelaAtiva);

      expect(closed, isFalse);
      expect(
        viewModel.actionError,
        'Sem conexão com a internet. Confira a rede e tente de novo.',
      );
      expect(costelaIn(viewModel).status, ListingStatus.active);
      expect(viewModel.isActing, isFalse);
    });

    test(
      'a listing no longer active says so and reads the list again',
      () async {
        final viewModel = await loaded();
        repository.actionFailure = ListingFailure.notActive;
        repository.mine = [jiboiaEncerrada];

        final edited = await viewModel.edit(
          costelaAtiva,
          const ListingChanges(quantity: 2),
        );
        await pumpEventQueue();

        expect(edited, isFalse);
        expect(viewModel.actionError, 'Esse anúncio não está mais ativo.');
        expect(viewModel.listings, [jiboiaEncerrada]);
        expect(viewModel.loadError, isNull);
      },
    );

    test('a listing that is gone says so and reads the list again', () async {
      final viewModel = await loaded();
      repository.actionFailure = ListingFailure.notFound;
      final listedBefore = repository.listed;

      await viewModel.close(costelaAtiva);
      await pumpEventQueue();

      expect(viewModel.actionError, 'Esse anúncio não existe mais.');
      expect(repository.listed, listedBefore + 1);
    });

    test('the next action clears the previous error', () async {
      final viewModel = await loaded();
      repository.actionFailure = ListingFailure.unknown;
      await viewModel.close(costelaAtiva);
      expect(viewModel.actionError, 'Algo deu errado. Tente de novo.');

      repository.actionFailure = null;
      await viewModel.close(costelaAtiva);

      expect(viewModel.actionError, isNull);
    });
  });
}
