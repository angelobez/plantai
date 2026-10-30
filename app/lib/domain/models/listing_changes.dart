/// What "Editar" changes in one of the donor's active listings
/// (`PATCH /v1/listings/:id`): only the fields that are not null are sent,
/// and at least one must be.
class ListingChanges {
  const ListingChanges({this.quantity, this.note})
    : assert(
        quantity != null || note != null,
        'ListingChanges needs at least one field',
      );

  /// How many seedlings are left: 1 to 99.
  final int? quantity;

  /// The new note, up to 200 characters after the trim; an empty one clears
  /// it.
  final String? note;
}
