import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/health/health_repository_remote.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/api_exception.dart';
import 'package:plantai/data/services/api/models/health_response.dart';
import 'package:plantai/domain/models/health_failure.dart';

/// An [ApiClient] that answers `getHealth` with a fixed body or error.
class _StubApiClient implements ApiClient {
  _StubApiClient({this.response, this.error});

  final HealthResponse? response;
  final Object? error;

  @override
  Future<HealthResponse> getHealth() async {
    if (error case final error?) throw error;
    return response!;
  }
}

void main() {
  test('returns the API and PostGIS versions', () async {
    final repository = HealthRepositoryRemote(
      apiClient: _StubApiClient(
        response: const HealthResponse(
          status: 'ok',
          apiVersion: '0.0.1',
          postgisVersion: '3.5.2',
        ),
      ),
    );

    final health = await repository.check();

    expect(health.apiVersion, '0.0.1');
    expect(health.postgisVersion, '3.5.2');
  });

  final failures = <String, (Object, HealthFailure)>{
    'API unreachable': (
      const ApiConnectionException(),
      HealthFailure.noConnection,
    ),
    'database down': (
      const ApiException(status: 503, code: ApiErrorCode.healthCheckFailed),
      HealthFailure.databaseDown,
    ),
    'app update required': (
      const ApiException(status: 426, code: ApiErrorCode.appUpdateRequired),
      HealthFailure.updateRequired,
    ),
    'unexpected API error': (
      const ApiException(status: 500, code: 'INTERNAL_ERROR'),
      HealthFailure.unknown,
    ),
    'error response that is not a problem': (
      const ApiException(status: 502),
      HealthFailure.unknown,
    ),
  };

  for (final MapEntry(key: name, value: (error, failure)) in failures.entries) {
    test('translates $name into HealthFailure.${failure.name}', () async {
      final repository = HealthRepositoryRemote(
        apiClient: _StubApiClient(error: error),
      );

      await expectLater(repository.check(), throwsA(failure));
    });
  }
}
