import '../../data/services/api/models/photo.dart';
import '../../data/services/api/models/plant.dart';

/// What the Novo anúncio form starts from: a plant of Meu jardim ("Doar
/// mudas" on the Tela da planta) or a new photo of the seedling with the
/// species found for it (the photo flow from Meus anúncios).
class ListingDraft {
  const ListingDraft({
    required this.photo,
    required this.commonName,
    this.species,
    this.plantId,
  });

  /// "Doar mudas" on the Tela da planta: the plant's photo, name and
  /// species.
  factory ListingDraft.fromPlant(Plant plant) => ListingDraft(
    photo: plant.photo,
    commonName: plant.commonName,
    species: switch (plant.species) {
      final species? => ListingDraftSpecies(
        id: species.id,
        scientificName: species.scientificName,
      ),
      null => null,
    },
    plantId: plant.id,
  );

  /// The photo the listing starts with; the form may swap it for a new one.
  final Photo photo;

  /// The name the form starts with, editable.
  final String commonName;

  /// Read-only in the form; null for a listing with only the name.
  final ListingDraftSpecies? species;

  /// The plant it comes from, when it comes from Meu jardim.
  final String? plantId;
}

/// The species of a [ListingDraft].
class ListingDraftSpecies {
  const ListingDraftSpecies({required this.id, required this.scientificName});

  final String id;
  final String scientificName;
}
