/// Why a listing call failed.
///
/// `ListingRepository` throws one of these; the listing ViewModels turn it
/// into a message or a screen.
enum ListingFailure implements Exception {
  /// The API did not answer (no network, or it is down).
  noConnection,

  /// The User has no phone or no donation location yet
  /// (`DONATION_PROFILE_REQUIRED`): the Primeiro anúncio comes first.
  donationProfileRequired,

  /// The listing, or the photo to publish it with, is not the User's or is
  /// gone (`NOT_FOUND`).
  notFound,

  /// The listing is no longer active (closed, donated or expired), so the
  /// donor's actions and the interest do not apply (`LISTING_NOT_ACTIVE`).
  notActive,

  /// "Doei algumas" with more seedlings than the listing has now
  /// (`INVALID_DONATION_COUNT`).
  invalidDonationCount,

  /// "Renovar" before the last 7 days before the expiry
  /// (`RENEWAL_NOT_ALLOWED`).
  renewalNotAllowed,

  /// "Tenho interesse" on the User's own listing (`OWN_LISTING`).
  ownListing,

  /// Anything else.
  unknown,
}
