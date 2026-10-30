import '../../../domain/models/listing_changes.dart';
import '../../../domain/models/listing_failure.dart';
import '../../../domain/models/new_listing.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/guard_api_call.dart';
import '../../services/api/models/listing.dart';
import 'listing_repository.dart';

/// [ListingRepository] backed by the API's `/v1/listings` and
/// `/v1/me/listings`.
class ListingRepositoryRemote extends ListingRepository {
  ListingRepositoryRemote({required this._apiClient});

  final ApiClient _apiClient;

  @override
  Future<MyListing> create(NewListing listing) async {
    final note = listing.note?.trim();
    final created = await _guard(
      () => _apiClient.post('/v1/listings', {
        'photoId': listing.photoId,
        'commonName': listing.commonName,
        'quantity': listing.quantity,
        'speciesId': ?listing.speciesId,
        'plantId': ?listing.plantId,
        if (note != null && note.isNotEmpty) 'note': note,
      }, MyListing.fromJson),
    );
    notifyListeners();
    return created;
  }

  @override
  Future<List<MyListing>> myListings() =>
      _guard(() => _apiClient.getList('/v1/me/listings', MyListing.fromJson));

  @override
  Future<MyListing> update(String id, ListingChanges changes) => _act(
    () => _apiClient.patch(_path(id), {
      'quantity': ?changes.quantity,
      'note': ?changes.note?.trim(),
    }, MyListing.fromJson),
  );

  @override
  Future<MyListing> close(String id) => _act(
    () => _apiClient.post('${_path(id)}/close', const {}, MyListing.fromJson),
  );

  static String _path(String id) => '/v1/listings/${Uri.encodeComponent(id)}';

  /// Runs one of the donor's actions and, once it worked, tells the
  /// listeners so Meus anúncios reads the list again.
  Future<MyListing> _act(Future<MyListing> Function() call) async {
    final listing = await _guard(call);
    notifyListeners();
    return listing;
  }

  static Future<T> _guard<T>(Future<T> Function() call) => guardApiCall(
    call,
    noConnection: ListingFailure.noConnection,
    onError: (code) => switch (code) {
      ApiErrorCode.donationProfileRequired =>
        ListingFailure.donationProfileRequired,
      ApiErrorCode.notFound => ListingFailure.notFound,
      ApiErrorCode.listingNotActive => ListingFailure.notActive,
      _ => ListingFailure.unknown,
    },
  );
}
