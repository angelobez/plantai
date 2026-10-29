import '../../../domain/models/health.dart';
import '../../../domain/models/health_failure.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_exception.dart';
import 'health_repository.dart';

/// [HealthRepository] backed by `GET /v1/health`. It is where the API's
/// errors become a [HealthFailure].
class HealthRepositoryRemote implements HealthRepository {
  HealthRepositoryRemote({required this._apiClient});

  final ApiClient _apiClient;

  @override
  Future<Health> check() async {
    try {
      final response = await _apiClient.getHealth();
      return Health(
        apiVersion: response.apiVersion,
        postgisVersion: response.postgisVersion,
      );
    } on ApiConnectionException {
      throw HealthFailure.noConnection;
    } on ApiException catch (error) {
      throw switch (error.code) {
        ApiErrorCode.healthCheckFailed => HealthFailure.databaseDown,
        ApiErrorCode.appUpdateRequired => HealthFailure.updateRequired,
        _ => HealthFailure.unknown,
      };
    }
  }
}
