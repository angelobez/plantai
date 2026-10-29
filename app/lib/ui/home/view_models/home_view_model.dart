import 'package:flutter/foundation.dart';

import '../../../data/repositories/health/health_repository.dart';
import '../../../domain/models/health.dart';
import '../../../domain/models/health_failure.dart';

/// What the home screen shows.
sealed class HomeState {
  const HomeState();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeConnected extends HomeState {
  const HomeConnected(this.health);

  final Health health;
}

class HomeFailed extends HomeState {
  const HomeFailed(this.failure);

  final HealthFailure failure;
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
      _setState(HomeConnected(await _healthRepository.check()));
    } on HealthFailure catch (failure) {
      _setState(HomeFailed(failure));
    } on Object {
      _setState(const HomeFailed(HealthFailure.unknown));
    }
  }

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
