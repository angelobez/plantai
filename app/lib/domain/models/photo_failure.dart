/// Why sending a photo failed.
///
/// `PhotoRepository` throws one of these; the Foto ViewModel turns it into a
/// message.
enum PhotoFailure implements Exception {
  /// The API did not answer (no network, or it is down). The photo is kept,
  /// so it can be sent again.
  noConnection,

  /// The User already sent 50 photos today (`PHOTO_DAILY_LIMIT`).
  dailyLimit,

  /// The API could not read the file as an image (`VALIDATION_FAILED`).
  notAnImage,

  /// Anything else.
  unknown,
}
