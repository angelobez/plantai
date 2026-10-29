/// A plant about to be saved in Meu jardim (`POST /v1/plants`).
class NewPlant {
  const NewPlant({
    required this.photoId,
    required this.commonName,
    this.speciesId,
  });

  /// The photo already sent, which becomes the plant's.
  final String photoId;

  /// 1 to 80 characters, without spaces at the ends.
  final String commonName;

  /// Null to save the plant with only the name.
  final String? speciesId;
}
