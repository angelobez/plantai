/// Why reading or changing the profile failed.
///
/// `ProfileRepository` throws one of these; the Perfil ViewModel turns it into
/// a message.
enum ProfileFailure implements Exception {
  /// The API did not answer (no network, or it is down).
  noConnection,

  /// Anything else.
  unknown,
}
