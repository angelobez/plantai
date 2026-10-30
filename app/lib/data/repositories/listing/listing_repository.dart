import 'package:flutter/foundation.dart';

import '../../../domain/models/listing_changes.dart';
import '../../../domain/models/new_listing.dart';
import '../../services/api/models/listing.dart';
import '../../services/location/location_service.dart';

/// Donation listings in the API (`/v1/listings` and `/v1/me/listings`).
///
/// Every method throws a `ListingFailure` when it fails. It notifies its
/// listeners after every change it makes to the User's listings (one
/// published, and later edited, donated, closed or renewed), so Meus
/// anúncios reads them again.
abstract class ListingRepository extends ChangeNotifier {
  /// Publishes [listing] for 30 days and answers it as in Meus anúncios.
  /// Without a phone or a donation location, fails with
  /// `ListingFailure.donationProfileRequired`.
  Future<MyListing> create(NewListing listing);

  /// The User's own listings, newest first, with the effective status.
  Future<List<MyListing>> myListings();

  // The donor's actions on an active listing. Another User's listing, or
  // one that is gone, fails with `ListingFailure.notFound`; one that is no
  // longer active (expired included) with `ListingFailure.notActive`.

  /// "Editar": applies [changes] to the listing [id] and answers it.
  Future<MyListing> update(String id, ListingChanges changes);

  /// "Doei algumas": [count] seedlings (1 up to the quantity) left the
  /// listing [id]; at zero it is donated. More than it has fails with
  /// `ListingFailure.invalidDonationCount`.
  Future<MyListing> donate(String id, int count);

  /// "Encerrar": closes the listing [id] for good and answers it.
  Future<MyListing> close(String id);

  /// "Renovar": the listing [id] expires 30 days from now. Before its last
  /// 7 days, fails with `ListingFailure.renewalNotAllowed`.
  Future<MyListing> renew(String id);

  /// Page [page] (from 1) of the active listings of other Users within
  /// 30 km of [from], nearest first; [nearbyPageSize] per page, so a shorter
  /// page is the last one. [from] goes in the `X-Search-Location` header,
  /// never in the URL.
  Future<List<NearbyListing>> nearby({
    required ApproximatePosition from,
    int page = 1,
  });

  /// The listing [id], with the distance from [from] (sent as in [nearby]),
  /// also when it is no longer active. Missing: `ListingFailure.notFound`.
  Future<ListingDetail> detail(String id, {required ApproximatePosition from});

  /// "Tenho interesse": records the User's interest in the listing [id]
  /// (once per User; asking again only reopens the chat) and answers the
  /// `wa.me` link to the donor's WhatsApp with the message ready, the only
  /// way the app gets the donor's phone. The User's own listing fails with
  /// `ListingFailure.ownListing`; one no longer active with
  /// `ListingFailure.notActive`; a missing one with `ListingFailure.notFound`.
  Future<Uri> interest(String id);
}

/// How many listings a full page of [ListingRepository.nearby] has.
const nearbyPageSize = 30;
