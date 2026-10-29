import 'package:flutter/foundation.dart';

import '../../../data/repositories/health/health_repository.dart';
import '../../../data/services/api/api_exception.dart';

/// What the home screen shows.
sealed class HomeState {
  const HomeState();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeConnected extends HomeState {
  const HomeConnected({required this.apiVersion, required this.postgisVersion});

  final String apiVersion;
  final String postgisVersion;
}

class HomeFailed extends HomeState {
  const HomeFailed(this.failure);

  final HomeFailure failure;
}

enum HomeFailure {
  /// The API did not answer (down, wrong address or no network).
  noConnection,

  /// The API answered, but its database is down.
  databaseDown,

  /// The API refuses this app version; retrying will not help.
  updateRequired,

  /// Anything else.
  unknown,
}

/// Checks the API health as soon as it is created, and again on [load].
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required this._healthRepository}) {
    load();
  }

  final HealthRepository _healthRepository;
  bool _disposed = false;

  HomeState _state = const HomeLoading();
  HomeState get state => _state;

  Future<void> load() async {
    _setState(const HomeLoading());
    try {
      final health = await _healthRepository.check();
      _setState(
        HomeConnected(
          apiVersion: health.apiVersion,
          postgisVersion: health.postgisVersion,
        ),
      );
    } on Object catch (error) {
      _setState(HomeFailed(_failureFor(error)));
    }
  }

  static HomeFailure _failureFor(Object error) => switch (error) {
    ApiConnectionException() => HomeFailure.noConnection,
    ApiException(code: ApiErrorCode.healthCheckFailed) =>
      HomeFailure.databaseDown,
    ApiException(code: ApiErrorCode.appUpdateRequired) =>
      HomeFailure.updateRequired,
    _ => HomeFailure.unknown,
  };

  void _setState(HomeState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
