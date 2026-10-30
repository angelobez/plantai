/// Why identifying a photo, or choosing a candidate, failed.
///
/// `IdentificationRepository` throws one of these; the Candidatos ViewModel
/// turns it into a screen (the daily limit) or a message.
enum IdentificationFailure implements Exception {
  /// The API did not answer (no network, or it is down).
  noConnection,

  /// The User already made today's 10 identifications
  /// (`IDENTIFICATION_DAILY_LIMIT`).
  dailyLimit,

  /// Pl@ntNet failed or timed out (`IDENTIFICATION_SERVICE_UNAVAILABLE`); it
  /// did not count against the limit.
  serviceUnavailable,

  /// The photo or the identification is not there (`NOT_FOUND`).
  notFound,

  /// This identification already has a choice
  /// (`IDENTIFICATION_ALREADY_CHOSEN`).
  alreadyChosen,

  /// Anything else.
  unknown,
}
