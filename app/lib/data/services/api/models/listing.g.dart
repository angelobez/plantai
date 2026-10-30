// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyListing _$MyListingFromJson(Map<String, dynamic> json) => MyListing(
  id: json['id'] as String,
  commonName: json['commonName'] as String,
  photo: Photo.fromJson(json['photo'] as Map<String, dynamic>),
  status: $enumDecode(
    _$ListingStatusEnumMap,
    json['status'],
    unknownValue: ListingStatus.closed,
  ),
  quantity: (json['quantity'] as num).toInt(),
  note: json['note'] as String?,
  interestCount: (json['interestCount'] as num).toInt(),
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  canRenew: json['canRenew'] as bool,
);

const _$ListingStatusEnumMap = {
  ListingStatus.active: 'active',
  ListingStatus.donated: 'donated',
  ListingStatus.closed: 'closed',
};

NearbyListing _$NearbyListingFromJson(Map<String, dynamic> json) =>
    NearbyListing(
      id: json['id'] as String,
      commonName: json['commonName'] as String,
      scientificName: json['scientificName'] as String?,
      photo: Photo.fromJson(json['photo'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num).toInt(),
      distanceKm: (json['distanceKm'] as num).toInt(),
      neighborhood: json['neighborhood'] as String,
    );

ListingDetail _$ListingDetailFromJson(Map<String, dynamic> json) =>
    ListingDetail(
      id: json['id'] as String,
      commonName: json['commonName'] as String,
      scientificName: json['scientificName'] as String?,
      photo: Photo.fromJson(json['photo'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num).toInt(),
      distanceKm: (json['distanceKm'] as num).toInt(),
      neighborhood: json['neighborhood'] as String,
      status: $enumDecode(
        _$ListingStatusEnumMap,
        json['status'],
        unknownValue: ListingStatus.closed,
      ),
      note: json['note'] as String?,
      donorFirstName: json['donorFirstName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      careGuide: json['careGuide'] == null
          ? null
          : CareGuide.fromJson(json['careGuide'] as Map<String, dynamic>),
    );
