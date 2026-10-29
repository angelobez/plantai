import '../../../domain/models/health.dart';

/// Checks that the API and its database are up.
abstract class HealthRepository {
  /// Throws [ApiException] when the API answers with an error and
  /// [ApiConnectionException] when it cannot be reached.
  Future<Health> check();
}
