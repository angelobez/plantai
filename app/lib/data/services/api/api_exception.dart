/// Stable `code` values from the API's `application/problem+json` errors
/// (docs/spec/modelo-de-dados-e-api.md, "Códigos de erro"; `ERROR_STATUS` in
/// `api/src/errors/domain-error.ts`).
enum ApiErrorCode {
  validationFailed('VALIDATION_FAILED'),
  notFound('NOT_FOUND'),
  appUpdateRequired('APP_UPDATE_REQUIRED'),
  unauthenticated('UNAUTHENTICATED'),
  invalidCredentials('INVALID_CREDENTIALS'),
  emailNotVerified('EMAIL_NOT_VERIFIED'),
  invalidCode('INVALID_CODE'),
  googleAccountLinkRefused('GOOGLE_ACCOUNT_LINK_REFUSED'),
  tooManyRequests('TOO_MANY_REQUESTS'),
  photoDailyLimit('PHOTO_DAILY_LIMIT'),
  identificationDailyLimit('IDENTIFICATION_DAILY_LIMIT'),
  identificationServiceUnavailable('IDENTIFICATION_SERVICE_UNAVAILABLE'),
  identificationAlreadyChosen('IDENTIFICATION_ALREADY_CHOSEN'),
  speciesAlreadySet('SPECIES_ALREADY_SET'),

  /// `202`: another request is writing the care guide; try again after
  /// [ApiException.retryAfter].
  careGuideGenerating('CARE_GUIDE_GENERATING'),
  internalError('INTERNAL_ERROR'),
  healthCheckFailed('HEALTH_CHECK_FAILED'),

  /// No code, or one this app version does not know.
  unknown(null);

  const ApiErrorCode(this.wire);

  /// The `code` as the API writes it; null for [unknown].
  final String? wire;

  /// The value for [code] as it came from the API; [unknown] when it is null
  /// or not one of these.
  static ApiErrorCode parse(String? code) {
    if (code == null) return unknown;
    for (final value in values) {
      if (value.wire == code) return value;
    }
    return unknown;
  }
}

/// The API answered with an error status.
///
/// [code] comes from the `application/problem+json` body; it is
/// [ApiErrorCode.unknown] when the response was not a problem document (a
/// proxy page, for example) or its code is not one the app knows.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    this.code = ApiErrorCode.unknown,
    this.retryAfter,
  });

  final int status;
  final ApiErrorCode code;

  /// The answer's `Retry-After` (in seconds), when it had one.
  final Duration? retryAfter;

  @override
  String toString() => 'ApiException($status, ${code.name})';
}

/// The API could not be reached: no network, connection refused or timeout.
class ApiConnectionException implements Exception {
  const ApiConnectionException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'ApiConnectionException($cause)';
}
