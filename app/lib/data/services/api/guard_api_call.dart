import 'api_exception.dart';

/// Runs [call], turning the API's errors into a repository's own failure:
/// [noConnection] when the API could not be reached, [onError] of the answer
/// when it refused. Repositories use it so the UI never sees an
/// [ApiException].
Future<T> guardApiCall<T>(
  Future<T> Function() call, {
  required Exception noConnection,
  required Exception Function(ApiErrorCode code) onError,
}) async {
  try {
    return await call();
  } on ApiConnectionException {
    throw noConnection;
  } on ApiException catch (error) {
    throw onError(error.code);
  }
}
