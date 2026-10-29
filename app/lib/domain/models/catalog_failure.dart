/// Why reading the Catalog failed.
///
/// `CatalogRepository` throws one of these; the Busca and Espécie ViewModels
/// turn it into a message.
enum CatalogFailure implements Exception {
  /// The API did not answer (no network, or it is down).
  noConnection,

  /// The species does not exist (`NOT_FOUND`).
  notFound,

  /// Anything else.
  unknown,
}
