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
  interestCount: (json['interestCount'] as num).toInt(),
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  canRenew: json['canRenew'] as bool,
);

const _$ListingStatusEnumMap = {
  ListingStatus.active: 'active',
  ListingStatus.donated: 'donated',
  ListingStatus.closed: 'closed',
};
