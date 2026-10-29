/// Stable `code` values from the API's `application/problem+json` errors
/// (docs/spec/modelo-de-dados-e-api.md, "Códigos de erro").
abstract final class ApiErrorCode {
  static const appUpdateRequired = 'APP_UPDATE_REQUIRED';
}

/// The API answered with an error status.
///
/// [code] comes from the `application/problem+json` body; it is null when the
/// response was not a problem document (a proxy page, for example).
class ApiException implements Exception {
  const ApiException({required this.status, this.code});

  final int status;
  final String? code;

  @override
  String toString() => 'ApiException($status, $code)';
}

/// The API could not be reached: no network, connection refused or timeout.
class ApiConnectionException implements Exception {
  const ApiConnectionException([this.cause]);

  final Object? cause;

  @override
  String toString() => 'ApiConnectionException($cause)';
}
