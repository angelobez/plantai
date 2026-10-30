/// The WhatsApp phone and the donation location about to be saved
/// (`PUT /v1/me/donation-profile`). The API rounds the point to its ~1 km
/// cell before saving and never sends it back.
class DonationProfile {
  const DonationProfile({
    required this.phone,
    this.latitude,
    this.longitude,
    required this.neighborhood,
  }) : assert(
         (latitude == null) == (longitude == null),
         'latitude and longitude come together',
       );

  /// As typed: with the area code, with or without +55, masked or not.
  final String phone;

  /// The point found by the GPS, or null (with [longitude]) to keep the one
  /// saved before.
  final double? latitude;
  final double? longitude;

  /// 1 to 60 characters, without spaces at the ends.
  final String neighborhood;
}
