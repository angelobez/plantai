import 'dart:async';

import 'package:plantai/data/repositories/health/health_repository.dart';
import 'package:plantai/domain/models/health.dart';

/// A [HealthRepository] whose answers the test controls.
///
/// Each [check] waits until the test calls [succeed] or [fail], so the loading
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

  void fail(Object error) => _take().completeError(error);

  Completer<Health> _take() {
    final pending = _pending;
    if (pending == null) {
      throw StateError('No check() is waiting for an answer');
    }
    _pending = null;
    return pending;
  }
}
