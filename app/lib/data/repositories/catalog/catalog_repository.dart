import '../../services/api/models/species.dart';
import '../../services/api/models/species_summary.dart';

/// The Catalog in the API (`/v1/species`).
///
/// Every method throws a `CatalogFailure` when it fails.
abstract class CatalogRepository {
  /// Species with a common or scientific name containing [term] (2 to 50
  /// characters, accents and capitals aside), at most 20, the names that
  /// start with it first.
  Future<List<SpeciesSummary>> search(String term);

  /// One species, with all its names.
  Future<Species> species(String id);
}
