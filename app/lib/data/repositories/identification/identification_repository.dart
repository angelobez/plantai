import '../../services/api/models/identification.dart';
import '../../services/api/models/species_summary.dart';

/// Identification by photo in the API (`/v1/identifications`).
///
/// Every method throws an `IdentificationFailure` when it fails.
abstract class IdentificationRepository {
  /// Asks Pl@ntNet about the photo [photoId], already sent. Counts against
  /// the User's 10 a day, even when not recognized.
  Future<Identification> identify(String photoId);

  /// Chooses the candidate at [candidateIndex] of [identificationId]: the
  /// species, now in the Catalog.
  Future<SpeciesSummary> choose(String identificationId, int candidateIndex);

  /// "Nenhuma destas" for [identificationId].
  Future<void> chooseNone(String identificationId);
}
