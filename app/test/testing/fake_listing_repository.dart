import 'dart:async';

import 'package:plantai/data/repositories/listing/listing_repository.dart';
import 'package:plantai/data/services/api/models/care_guide.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/data/services/api/models/photo.dart';
import 'package:plantai/domain/models/listing_changes.dart';
import 'package:plantai/data/services/location/location_service.dart';
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

/// A neighbor's listing in the same cell ("menos de 1 km").
final costelaPerto = NearbyListing(
  id: '0190e0d4-0000-7000-8000-0000000000d1',
  commonName: 'Costela-de-adão',
  scientificName: 'Monstera deliciosa',
  photo: costelaPhoto,
  quantity: 3,
  distanceKm: 0,
  neighborhood: 'Vila Mariana',
);

/// A neighbor's listing published with only a name, 2 km away.
final espadaLonge = NearbyListing(
  id: '0190e0d4-0000-7000-8000-0000000000d2',
  commonName: 'Espada-de-são-jorge',
  scientificName: null,
  photo: costelaPhoto,
  quantity: 1,
  distanceKm: 2,
  neighborhood: 'Saúde',
);

/// [listing] as `GET /v1/listings/:id` would answer it: published by Marina
/// on 27/10 at noon in São Paulo, with a note and no care guide.
ListingDetail detailOf(
  NearbyListing listing, {
  ListingStatus status = ListingStatus.active,
  String? note = 'Mudas já enraizadas, pegar à tarde.',
  CareGuide? careGuide,
}) => ListingDetail(
  id: listing.id,
  commonName: listing.commonName,
  scientificName: listing.scientificName,
  photo: listing.photo,
  quantity: listing.quantity,
  distanceKm: listing.distanceKm,
  neighborhood: listing.neighborhood,
  status: status,
  note: note,
  donorFirstName: 'Marina',
  createdAt: DateTime.utc(2026, 10, 27, 15),
  careGuide: careGuide,
);

/// The link [FakeListingRepository.interest] answers for the listing [id]:
/// Marina's WhatsApp, with the message about it.
Uri whatsappUrlOf(String id) => Uri.https('wa.me', '/5511987654321', {
  'text': 'Oi, Marina! Vi no PlantAí seu anúncio $id e tenho interesse.',
});

/// A [ListingRepository] the test drives: [myListings] answers [mine], and
/// [create] puts a new active listing at the top of it, telling the
/// listeners. Every call throws [failure] when set (or [createFailures],
/// one per [create], first). It records what [create] got in [created].
///
/// The donor's actions ([update], [donate], [close], [renew]) change the
/// listing in [mine] and tell the listeners, like the API (a renewed one
/// expires at [renewedExpiresAt]); [actionFailure] makes only them fail.
/// They record what they got in [updates], [donations], [closed] and
/// [renewed].
///
/// [interest] answers [whatsappUrlOf] the listing, or throws
/// [interestFailure]; it records the ids it got in [interests].
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

  /// What [donate] got, in order: the listing id and the count.
  final donations = <(String, int)>[];

  /// The ids [close] got, in order.
  final closed = <String>[];

  /// The ids [renew] got, in order.
  final renewed = <String>[];

  /// The expiry [renew] gives: 30 days after 30/10 at noon in São Paulo.
  DateTime renewedExpiresAt = DateTime.utc(2026, 11, 29, 15);

  /// Thrown by the next [interest] calls, until set back to null.
  ListingFailure? interestFailure;

  /// The ids [interest] got, in order.
  final interests = <String>[];

  /// How many times [myListings] was called.
  int listed = 0;

  /// Every listing near the searcher, nearest first; [nearby] pages it
  /// [nearbyPageSize] at a time.
  List<NearbyListing> nearbyListings = [];

  /// What [detail] answers, by id; a missing id is
  /// `ListingFailure.notFound`.
  final details = <String, ListingDetail>{};

  /// What [nearby] got, in order: the position and the page.
  final nearbyCalls = <(ApproximatePosition, int)>[];

  /// What [detail] got, in order: the id and the position.
  final detailCalls = <(String, ApproximatePosition)>[];

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
  Future<MyListing> donate(String id, int count) {
    donations.add((id, count));
    return _act(id, (listing) {
      if (count > listing.quantity) throw ListingFailure.invalidDonationCount;
      final left = listing.quantity - count;
      return _copy(
        listing,
        note: listing.note,
        quantity: left,
        status: left == 0 ? ListingStatus.donated : null,
        canRenew: left == 0 ? false : null,
      );
    });
  }

  @override
  Future<MyListing> renew(String id) {
    renewed.add(id);
    return _act(id, (listing) {
      if (!listing.canRenew) throw ListingFailure.renewalNotAllowed;
      return _copy(
        listing,
        note: listing.note,
        expiresAt: renewedExpiresAt,
        canRenew: false,
      );
    });
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
    DateTime? expiresAt,
    bool? canRenew,
  }) => MyListing(
    id: listing.id,
    commonName: listing.commonName,
    photo: listing.photo,
    status: status ?? listing.status,
    quantity: quantity ?? listing.quantity,
    note: note,
    interestCount: listing.interestCount,
    expiresAt: expiresAt ?? listing.expiresAt,
    canRenew: canRenew ?? listing.canRenew,
  );

  @override
  Future<List<NearbyListing>> nearby({
    required ApproximatePosition from,
    int page = 1,
  }) async {
    nearbyCalls.add((from, page));
    await _answer();
    return nearbyListings
        .skip((page - 1) * nearbyPageSize)
        .take(nearbyPageSize)
        .toList();
  }

  @override
  Future<ListingDetail> detail(
    String id, {
    required ApproximatePosition from,
  }) async {
    detailCalls.add((id, from));
    await _answer();
    return details[id] ?? (throw ListingFailure.notFound);
  }

  @override
  Future<Uri> interest(String id) async {
    interests.add(id);
    await gate?.future;
    final failure = interestFailure ?? this.failure;
    if (failure != null) throw failure;
    return whatsappUrlOf(id);
  }
}
