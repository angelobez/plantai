/// Why a Meu jardim call failed.
///
/// `GardenRepository` throws one of these; the Jardim and Planta ViewModels
/// and the save turn it into a message.
enum GardenFailure implements Exception {
  /// The API did not answer (no network, or it is down).
  noConnection,

  /// The plant (or the photo to save it with) is not the User's, or is gone
  /// (`NOT_FOUND`).
  notFound,

  /// The plant has a species already, which never changes
  /// (`SPECIES_ALREADY_SET`).
  speciesAlreadySet,

  /// Anything else.
  unknown,
}
