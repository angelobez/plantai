import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'models/health_response.dart';
import 'models/problem_details.dart';

/// The PlantAí API over HTTP.
///
/// Every call either returns the parsed body or throws [ApiException] (the API
/// answered with an error) or [ApiConnectionException] (it could not be
/// reached).
class ApiClient {
  ApiClient({required String baseUrl, required String appVersion})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      )..interceptors.add(AppVersionInterceptor(appVersion));

  final Dio _dio;

  Future<HealthResponse> getHealth() =>
      _get('/v1/health', HealthResponse.fromJson);

  Future<T> _get<T>(
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

  static Exception _toApiError(DioException error) {
    final response = error.response;
    if (response == null) return ApiConnectionException(error);
    final status = response.statusCode ?? 0;
    return ApiException(status: status, code: _problemCode(response.data));
  }

  static String? _problemCode(Object? body) {
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
