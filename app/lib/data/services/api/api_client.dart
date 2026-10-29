import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'models/problem_details.dart';
import '../session/session_store.dart';
import 'session_refresh_interceptor.dart';
import 'update_required.dart';

/// The PlantAí API over HTTP.
///
/// Every call either returns the parsed body or throws [ApiException] (the API
/// answered with an error) or [ApiConnectionException] (it could not be
/// reached). A `426 APP_UPDATE_REQUIRED` on any call also raises
/// [UpdateRequired].
///
/// Repositories call [get], [post] and [postWithoutBody]; cross-cutting
/// behavior goes in as another [Interceptor] (the session's `Authorization`
/// header is [BearerInterceptor]).
class ApiClient {
  ApiClient({
    required String baseUrl,
    required String appVersion,
    required UpdateRequired updateRequired,
    required SessionStore sessionStore,
    HttpClientAdapter? httpClientAdapter,
  }) : _dio =
           Dio(
               BaseOptions(
                 baseUrl: baseUrl,
                 connectTimeout: const Duration(seconds: 5),
                 sendTimeout: const Duration(seconds: 10),
                 receiveTimeout: const Duration(seconds: 10),
               ),
             )
             ..interceptors.addAll([
               AppVersionInterceptor(appVersion),
               BearerInterceptor(sessionStore),
               UpdateRequiredInterceptor(updateRequired),
             ]) {
    _dio.interceptors.add(SessionRefreshInterceptor(_dio, sessionStore));
    if (httpClientAdapter != null) _dio.httpClientAdapter = httpClientAdapter;
  }

  final Dio _dio;

  /// `GET` [path] and parse its JSON object body with [fromJson].
  Future<T> get<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _toApiError(error);
    }
  }

  /// `POST` [body] as JSON to [path] and parse its JSON object answer with
  /// [fromJson].
  Future<T> post<T>(
    String path,
    Map<String, Object?> body,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw _toApiError(error);
    }
  }

  /// `POST` [body] as JSON to [path], for routes that answer without a body
  /// (`202`, `204`).
  Future<void> postWithoutBody(String path, Map<String, Object?> body) async {
    try {
      await _dio.post<void>(path, data: body);
    } on DioException catch (error) {
      throw _toApiError(error);
    }
  }

  static Exception _toApiError(DioException error) {
    final response = error.response;
    if (response == null) return ApiConnectionException(error);
    final status = response.statusCode ?? 0;
    return ApiException(status: status, code: problemCode(response.data));
  }

  /// The `code` of an `application/problem+json` body, or null when [body] is
  /// not one.
  static String? problemCode(Object? body) {
    if (body is! Map<String, dynamic>) return null;
    try {
      return ProblemDetails.fromJson(body).code;
    } on Object {
      return null;
    }
  }
}

/// Sends the app version on every request, so the API can answer `426
/// APP_UPDATE_REQUIRED` to versions below its minimum.
class AppVersionInterceptor extends Interceptor {
  AppVersionInterceptor(this.appVersion);

  static const header = 'X-App-Version';

  final String appVersion;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[header] = appVersion;
    handler.next(options);
  }
}

/// Sends `Authorization: Bearer <access token>` while there is a session.
///
/// The API answers `401 UNAUTHENTICATED` to a missing, invalid or expired
/// token; [SessionRefreshInterceptor] renews the session on that answer.
class BearerInterceptor extends Interceptor {
  BearerInterceptor(this.sessionStore);

  final SessionStore sessionStore;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = sessionStore.session;
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }
}

/// Raises [UpdateRequired] when any call gets `426 APP_UPDATE_REQUIRED`. The
/// error still reaches the caller.
class UpdateRequiredInterceptor extends Interceptor {
  UpdateRequiredInterceptor(this.updateRequired);

  final UpdateRequired updateRequired;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response?.statusCode == 426 &&
        ApiClient.problemCode(response?.data) ==
            ApiErrorCode.appUpdateRequired) {
      updateRequired.raise();
    }
    handler.next(err);
  }
}
