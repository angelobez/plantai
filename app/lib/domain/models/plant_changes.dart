/// What to change in a plant of Meu jardim (`PATCH /v1/plants/:id`): only
/// the fields that are not null are sent, and at least one must be.
class PlantChanges {
  const PlantChanges({this.commonName, this.speciesId})
    : assert(
        commonName != null || speciesId != null,
        'PlantChanges needs at least one field',
      );

  /// The new name: 1 to 80 characters, without spaces at the ends.
  final String? commonName;

  /// The species of a plant saved with only a name. It is set once: a plant
  /// that has one fails with `GardenFailure.speciesAlreadySet`.
  final String? speciesId;
}
