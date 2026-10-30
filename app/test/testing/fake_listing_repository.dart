import 'dart:async';

import 'package:plantai/data/repositories/listing/listing_repository.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/data/services/api/models/photo.dart';
import 'package:plantai/domain/models/listing_changes.dart';
import 'package:plantai/domain/models/listing_failure.dart';
import 'package:plantai/domain/models/new_listing.dart';

final costelaPhoto = Photo(
  id: '0190e0d4-0000-7000-8000-0000000000f3',
  url: 'https://photo-storage.fake/photos/f3.jpg',
  expiresAt: DateTime.utc(2026, 11, 3, 15),
);

/// An active listing expiring on 4/11 at noon in São Paulo, with 3
/// interested Users.
final costelaAtiva = MyListing(
  id: '0190e0d4-0000-7000-8000-0000000000b1',
  commonName: 'Costela-de-adão',
  photo: costelaPhoto,
  status: ListingStatus.active,
  quantity: 3,
  note: 'Pegar à tarde',
  interestCount: 3,
  expiresAt: DateTime.utc(2026, 11, 4, 15),
  canRenew: true,
);

/// A listing whose seedlings all went.
final espadaDoada = MyListing(
  id: '0190e0d4-0000-7000-8000-0000000000b2',
  commonName: 'Espada-de-são-jorge',
  photo: costelaPhoto,
  status: ListingStatus.donated,
  quantity: 0,
  interestCount: 5,
  expiresAt: DateTime.utc(2026, 11, 20, 15),
  canRenew: false,
);

/// A listing that expired, which the API answers as closed.
final jiboiaEncerrada = MyListing(
  id: '0190e0d4-0000-7000-8000-0000000000b3',
  commonName: 'Jiboia',
  photo: costelaPhoto,
  status: ListingStatus.closed,
  quantity: 2,
  interestCount: 0,
  expiresAt: DateTime.utc(2026, 10, 20, 15),
  canRenew: false,
);

/// A [ListingRepository] the test drives: [myListings] answers [mine], and
/// [create] puts a new active listing at the top of it, telling the
/// listeners. Every call throws [failure] when set (or [createFailures],
/// one per [create], first). It records what [create] got in [created].
///
/// The donor's actions ([update], [close]) change the listing in [mine] and
/// tell the listeners, like the API; [actionFailure] makes only them fail.
/// They record what they got in [updates] and [closed].
///
/// Set [gate] to hold every call until the test completes it.
class FakeListingRepository extends ListingRepository {
  FakeListingRepository({List<MyListing>? mine}) : mine = mine ?? [];

  /// What [myListings] answers, newest first.
  List<MyListing> mine;

  /// Thrown by the next calls, until set back to null.
  ListingFailure? failure;

  /// Thrown by the next [create] calls, one each, before [failure].
  final createFailures = <ListingFailure>[];

  /// When set, calls wait for it before answering.
  Completer<void>? gate;

  /// What [create] got, in order (also the failed ones).
  final created = <NewListing>[];

  /// Thrown by the next donor actions, until set back to null.
  ListingFailure? actionFailure;

  /// What [update] got, in order: the listing id and the changes.
  final updates = <(String, ListingChanges)>[];

  /// The ids [close] got, in order.
  final closed = <String>[];

  /// How many times [myListings] was called.
  int listed = 0;

  Future<void> _answer() async {
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }

  @override
  Future<MyListing> create(NewListing listing) async {
    created.add(listing);
    await gate?.future;
    if (createFailures.isNotEmpty) throw createFailures.removeAt(0);
    await _answer();
    final published = MyListing(
      id: 'listing-${created.length}',
      commonName: listing.commonName,
      photo: Photo(
        id: listing.photoId,
        url: 'https://photo-storage.fake/photos/${listing.photoId}.jpg',
        expiresAt: DateTime.utc(2026, 11, 3, 15),
      ),
      status: ListingStatus.active,
      quantity: listing.quantity,
      interestCount: 0,
      expiresAt: DateTime.utc(2026, 11, 29, 15),
      canRenew: false,
    );
    mine = [published, ...mine];
    notifyListeners();
    return published;
  }

  @override
  Future<List<MyListing>> myListings() async {
    listed++;
    await _answer();
    return List.of(mine);
  }

  @override
  Future<MyListing> update(String id, ListingChanges changes) {
    updates.add((id, changes));
    final note = changes.note?.trim();
    return _act(
      id,
      (listing) => _copy(
        listing,
        quantity: changes.quantity ?? listing.quantity,
        note: note == null ? listing.note : (note.isEmpty ? null : note),
      ),
    );
  }

  @override
  Future<MyListing> close(String id) {
    closed.add(id);
    return _act(
      id,
      (listing) => _copy(
        listing,
        note: listing.note,
        status: ListingStatus.closed,
        canRenew: false,
      ),
    );
  }

  Future<MyListing> _act(
    String id,
    MyListing Function(MyListing listing) change,
  ) async {
    await gate?.future;
    final failure = actionFailure ?? this.failure;
    if (failure != null) throw failure;
    final index = mine.indexWhere((listing) => listing.id == id);
    if (index < 0) throw ListingFailure.notFound;
    if (mine[index].status != ListingStatus.active) {
      throw ListingFailure.notActive;
    }
    final changed = change(mine[index]);
    mine = [...mine]..[index] = changed;
    notifyListeners();
    return changed;
  }

  /// [listing] with the given fields; [note] is always replaced.
  static MyListing _copy(
    MyListing listing, {
    required String? note,
    int? quantity,
    ListingStatus? status,
    bool? canRenew,
  }) => MyListing(
    id: listing.id,
    commonName: listing.commonName,
    photo: listing.photo,
    status: status ?? listing.status,
    quantity: quantity ?? listing.quantity,
    note: note,
    interestCount: listing.interestCount,
    expiresAt: listing.expiresAt,
    canRenew: canRenew ?? listing.canRenew,
  );
}
