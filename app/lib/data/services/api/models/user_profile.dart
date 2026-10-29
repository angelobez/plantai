import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

/// The User as `GET /v1/me` (and the `user` of every sign-in) answers it.
@JsonSerializable(createToJson: false)
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.donationLocation,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  final String id;
  final String name;
  final String email;

  /// Null until the first listing (v0.3).
  final String? phone;

  /// Null until the first listing (v0.3).
  final DonationLocation? donationLocation;
}

@JsonSerializable(createToJson: false)
class DonationLocation {
  const DonationLocation({required this.neighborhood});

  factory DonationLocation.fromJson(Map<String, dynamic> json) =>
      _$DonationLocationFromJson(json);

  final String neighborhood;
}
