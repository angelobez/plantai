import 'package:flutter/foundation.dart';

import '../../domain/models/auth_failure.dart';

/// For an entry screen's ViewModel: keeps the last attempt that failed for
/// lack of connection, so the screen can offer "Tentar de novo" next to the
/// message (`FormMessage.onRetry`). [T] is what the attempt answers, such as
/// where "Entrar" leads.
mixin RetryWhenOffline<T> on ChangeNotifier {
  Future<T> Function()? _retry;

  /// Whether the last attempt failed for lack of connection.
  bool get canRetry => _retry != null;

  /// Runs again the attempt that failed for lack of connection.
  Future<T> retry() {
    final attempt = _retry;
    if (attempt == null) throw StateError('No attempt failed offline');
    return attempt();
  }

  /// Forgets the failed attempt; each new attempt starts with it.
  @protected
  void clearRetry() => _retry = null;

  /// Keeps [attempt] for [retry] when it ended in [failure] for lack of
  /// connection.
  @protected
  void offerRetry(AuthFailure failure, Future<T> Function() attempt) {
    _retry = failure == AuthFailure.noConnection ? attempt : null;
  }
}
