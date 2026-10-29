import '../../../domain/models/health.dart';
import '../../../domain/models/health_failure.dart';

/// Checks that the API and its database are up.
abstract class HealthRepository {
  /// Throws a [HealthFailure] when the check fails.
  Future<Health> check();
}
