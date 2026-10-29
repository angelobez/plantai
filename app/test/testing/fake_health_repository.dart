import 'dart:async';

import 'package:plantai/data/repositories/health/health_repository.dart';
import 'package:plantai/domain/models/health.dart';
import 'package:plantai/domain/models/health_failure.dart';

/// A [HealthRepository] whose answers the test controls.
///
/// Each [check] waits until the test calls [succeed], [fail] or
/// [throwUnexpected], so the loading
/// state can be observed before the answer arrives.
class FakeHealthRepository implements HealthRepository {
  Completer<Health>? _pending;
  int calls = 0;

  @override
  Future<Health> check() {
    calls++;
    _pending = Completer<Health>();
    return _pending!.future;
  }

  void succeed({String apiVersion = '0.0.0', String postgisVersion = '3.5.2'}) {
    _take().complete(
      Health(apiVersion: apiVersion, postgisVersion: postgisVersion),
    );
  }

  /// Fails the pending check the way the real repository does.
  void fail(HealthFailure failure) => _take().completeError(failure);

  /// Fails the pending check with an error the contract does not promise (a
  /// bug, for example).
  void throwUnexpected(Object error) => _take().completeError(error);

  Completer<Health> _take() {
    final pending = _pending;
    if (pending == null) {
      throw StateError('No check() is waiting for an answer');
    }
    _pending = null;
    return pending;
  }
}
