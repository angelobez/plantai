import 'package:json_annotation/json_annotation.dart';

import 'care_guide.dart';
import 'photo.dart';

part 'listing.g.dart';

/// A listing's effective status, as every API response shows it: an
/// `active` listing past its expiry already comes as [closed].
@JsonEnum()
enum ListingStatus {
  active,
  donated,
  closed;

  /// Doado and Encerrado: dimmed in Meus anúncios, with no actions.
  bool get isOver => this != active;
}

/// One of the donor's listings, as `GET /v1/me/listings` answers it; also
/// the answer of `POST /v1/listings` and of the donor's actions.
@JsonSerializable(createToJson: false)
class MyListing {
  const MyListing({
    required this.id,
    required this.commonName,
    required this.photo,
    required this.status,
    required this.quantity,
    this.note,
    required this.interestCount,
    required this.expiresAt,
    required this.canRenew,
  });

  factory MyListing.fromJson(Map<String, dynamic> json) =>
      _$MyListingFromJson(json);

  final String id;
  final String commonName;
  final Photo photo;

  /// An unknown status (from a newer API) shows as [ListingStatus.closed],
  /// with no actions.
  @JsonKey(unknownEnumValue: ListingStatus.closed)
  final ListingStatus status;

  /// Seedlings left; 0 only once donated.
  final int quantity;

  /// The donor's note ("pegar à tarde"); null without one. "Editar"
  /// starts from it.
  final String? note;

  /// How many Users tapped "Tenho interesse"; never who.
  final int interestCount;

  /// Publishing or renewing + 30 days.
  final DateTime expiresAt;

  /// Whether "Renovar" shows: active and within 7 days of [expiresAt].
  final bool canRenew;
}

/// A neighbor's listing near the searcher, as `GET /v1/listings/nearby`
/// answers it. Never the donor's phone nor the listing's point.
@JsonSerializable(createToJson: false)
class NearbyListing {
  const NearbyListing({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.photo,
    required this.quantity,
    required this.distanceKm,
    required this.neighborhood,
  });

  factory NearbyListing.fromJson(Map<String, dynamic> json) =>
      _$NearbyListingFromJson(json);

  final String id;
  final String commonName;

  /// Null for a listing published with only a name.
  final String? scientificName;
  final Photo photo;

  /// Seedlings left.
  final int quantity;

  /// Rounded by the API to the center of the listing's ~1 km cell; 0 is
  /// "menos de 1 km".
  final int distanceKm;

  /// The donor's, when publishing.
  final String neighborhood;
}

/// One listing as `GET /v1/listings/:id` answers it: also a listing that is
/// no longer active, with its effective [status]. Never the donor's phone.
@JsonSerializable(createToJson: false)
class ListingDetail {
  const ListingDetail({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.photo,
    required this.quantity,
    required this.distanceKm,
    required this.neighborhood,
    required this.status,
    required this.note,
    required this.donorFirstName,
    required this.createdAt,
    required this.careGuide,
  });

  factory ListingDetail.fromJson(Map<String, dynamic> json) =>
      _$ListingDetailFromJson(json);

  final String id;
  final String commonName;

  /// Null for a listing published with only a name.
  final String? scientificName;
  final Photo photo;

  /// Seedlings left.
  final int quantity;

  /// As in [NearbyListing.distanceKm].
  final int distanceKm;
  final String neighborhood;

  /// An unknown status (from a newer API) shows as [ListingStatus.closed]:
  /// not available.
  @JsonKey(unknownEnumValue: ListingStatus.closed)
  final ListingStatus status;

  /// The donor's note, if any.
  final String? note;

  /// "Doado por Marina".
  final String donorFirstName;

  /// When it was published: "Anunciado há X dias".
  final DateTime createdAt;

  /// The species' care guide when it is ready; the detail never waits for
  /// one.
  final CareGuide? careGuide;
}
