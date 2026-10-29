import 'package:dio/dio.dart';

import '../session/session_store.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'models/auth_tokens.dart';

/// Renews the session on `401 UNAUTHENTICATED` and repeats the call once.
///
/// - Calls that get the `401` at the same time share **one**
///   `POST /v1/auth/refresh`; the others wait for it.
/// - A call sent with an access token that was already replaced is only
///   repeated, with the new one.
/// - The refresh answering `UNAUTHENTICATED` (expired or revoked) clears the
///   session, which takes the router to Login; the caller gets the original
///   `401`.
/// - Any other refresh failure (no network, a `500`) keeps the session and
///   reaches the caller as that failure.
class SessionRefreshInterceptor extends Interceptor {
  SessionRefreshInterceptor(this._dio, this._sessionStore);

  static const refreshPath = '/v1/auth/refresh';

  /// Marks the refresh itself and the repeated calls, so neither is renewed
  /// again.
  static const _skip = 'sessionRefresh.skip';

  /// Which access token a call went out with, to tell a stale `401` (another
  /// call already renewed) from one that needs a refresh.
  static const _sentWith = 'sessionRefresh.sentWith';

  final Dio _dio;
  final SessionStore _sessionStore;

  /// The refresh in flight, shared by every call that got a `401` meanwhile.
  Future<void>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_sentWith] = _sessionStore.session?.accessToken;
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final session = _sessionStore.session;
    if (!_isUnauthenticated(err) ||
        options.extra[_skip] == true ||
        session == null) {
      return handler.next(err);
    }

    if (options.extra[_sentWith] == session.accessToken) {
      try {
        await (_refreshing ??= _refresh(session)
            .whenComplete(() => _refreshing = null));
      } on _SessionEnded {
        return handler.next(err);
      } on DioException catch (refreshError) {
        return handler.next(refreshError);
      }
    }

    try {
      options.extra[_skip] = true;
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<void> _refresh(Session session) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refreshToken': session.refreshToken},
        options: Options(extra: {_skip: true}),
      );
    } on DioException catch (error) {
      if (!_isUnauthenticated(error)) rethrow;
      // Only end the session that was refused, not one started meanwhile.
      if (_sessionStore.session == session) await _sessionStore.clear();
      throw const _SessionEnded();
    }
    final tokens = AuthTokens.fromJson(response.data ?? const {});
    await _sessionStore.save(
      Session(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      ),
    );
  }

  static bool _isUnauthenticated(DioException error) {
    final response = error.response;
    return response?.statusCode == 401 &&
        ApiClient.problemCode(response?.data) == ApiErrorCode.unauthenticated;
  }
}

/// The refresh token was refused: the session is over.
class _SessionEnded implements Exception {
  const _SessionEnded();
}
