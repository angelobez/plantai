/// Why signing up or in failed, in terms the entry screens care about.
///
/// `AuthRepository` throws one of these; each screen's ViewModel turns it into
/// a message (`authFailureMessage`).
enum AuthFailure implements Exception {
  /// The code is wrong, expired, already used or out of attempts.
  invalidCode,

  /// E-mail or password wrong; the same for an e-mail without an account.
  invalidCredentials,

  /// The password is right, but the e-mail was never confirmed. The API has
  /// sent a new code.
  emailNotVerified,

  /// The Google account cannot be joined to the existing one: sign in with the
  /// password.
  googleAccountLinkRefused,

  /// Too many attempts; wait and try again.
  tooManyRequests,

  /// The API refused what was typed (the app validates first, so it is rare).
  validationFailed,

  /// The API did not answer (no network, or it is down).
  noConnection,

  /// The API refuses this app version; the router already shows "Atualize".
  updateRequired,

  /// Anything else.
  unknown,
}
