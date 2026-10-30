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

  /// Anything else.
  unknown,
}
