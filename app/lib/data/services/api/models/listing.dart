import 'package:json_annotation/json_annotation.dart';

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
