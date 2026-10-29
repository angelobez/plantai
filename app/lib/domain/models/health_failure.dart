/// Why the health check failed, in terms the UI cares about.
///
/// `HealthRepository.check` throws one of these; it is the only error the
/// layers above the repository need to know.
enum HealthFailure implements Exception {
  /// The API did not answer (down, wrong address or no network).
  noConnection,

  /// The API answered, but its database is down.
  databaseDown,

  /// The API refuses this app version; retrying will not help.
  updateRequired,

  /// Anything else.
  unknown,
}
