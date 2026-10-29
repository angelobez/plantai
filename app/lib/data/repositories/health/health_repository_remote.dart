import '../../../domain/models/health.dart';
import '../../services/api/api_client.dart';
import 'health_repository.dart';

/// [HealthRepository] backed by `GET /v1/health`.
class HealthRepositoryRemote implements HealthRepository {
  HealthRepositoryRemote({required this._apiClient});

  final ApiClient _apiClient;

  @override
  Future<Health> check() async {
    final response = await _apiClient.getHealth();
    return Health(
      apiVersion: response.apiVersion,
      postgisVersion: response.postgisVersion,
    );
  }
}
