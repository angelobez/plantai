/// The WhatsApp phone and the donation location about to be saved
/// (`PUT /v1/me/donation-profile`). The API rounds the point to its ~1 km
/// cell before saving and never sends it back.
class DonationProfile {
  const DonationProfile({
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.neighborhood,
  });

  /// As typed: with the area code, with or without +55, masked or not.
  final String phone;
  final double latitude;
  final double longitude;

  /// 1 to 60 characters, without spaces at the ends.
  final String neighborhood;
}
