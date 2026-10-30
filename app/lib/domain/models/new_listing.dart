/// A listing about to be published (`POST /v1/listings`).
class NewListing {
  const NewListing({
    required this.photoId,
    required this.commonName,
    required this.quantity,
    this.speciesId,
    this.plantId,
    this.note,
  });

  /// One of the User's photos: the plant's, or a new one of the seedling.
  final String photoId;

  /// 1 to 80 characters, without spaces at the ends.
  final String commonName;

  /// 1 to 99.
  final int quantity;

  /// Null for a listing with only the name.
  final String? speciesId;

  /// The plant of Meu jardim it came from, if any.
  final String? plantId;

  /// Up to 200 characters; null or empty for none.
  final String? note;
}
