// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  phone: json['phone'] as String?,
  donationLocation: json['donationLocation'] == null
      ? null
      : DonationLocation.fromJson(
          json['donationLocation'] as Map<String, dynamic>,
        ),
);

DonationLocation _$DonationLocationFromJson(Map<String, dynamic> json) =>
    DonationLocation(neighborhood: json['neighborhood'] as String);
