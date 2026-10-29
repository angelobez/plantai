import 'package:flutter/foundation.dart';

import '../../../data/repositories/garden/garden_repository.dart';
import '../../../data/services/api/models/plant.dart';
import '../../../domain/models/garden_failure.dart';
import '../garden_failure_message.dart';

/// The Jardim tab: the User's plants, newest first.
///
/// [load] shows the loading state; [refresh] (pull to refresh) reads the
/// list again while the old one stays on screen. A change made through the
/// [GardenRepository] (a plant saved, renamed or removed) refreshes it too.
/// Only the newest read counts: an older answer that comes late is dropped.
class GardenViewModel extends ChangeNotifier {
  GardenViewModel({required this._gardenRepository}) {
    _gardenRepository.addListener(_onGardenChanged);
  }

  final GardenRepository _gardenRepository;

  /// Null until the first answer.
  List<PlantSummary>? _plants;
  List<PlantSummary>? get plants => _plants;

  /// Whether the garden was read and has no plant (the invitation).
  bool get isEmpty => _plants?.isEmpty ?? false;

  /// True while the first read (or the one after an error) is running.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Why the last read failed; shown over the list when there is one.
  String? _loadError;
  String? get loadError => _loadError;

  /// Whether reading again makes sense for [loadError].
  bool _canRetry = false;
  bool get canRetry => _canRetry;

  int _run = 0;
  bool _disposed = false;

  /// Reads the garden, showing the loading state.
  Future<void> load() => _read(showLoading: true);

  /// Reads the garden again, keeping the current list on screen.
  Future<void> refresh() => _read(showLoading: _plants == null);

  Future<void> _read({required bool showLoading}) async {
    final run = ++_run;
    _isLoading = showLoading;
    if (showLoading) _loadError = null;
    _notify();
    try {
      final plants = await _gardenRepository.plants();
      if (!_isCurrent(run)) return;
      _plants = plants;
      _loadError = null;
      _canRetry = false;
    } on GardenFailure catch (failure) {
      if (!_isCurrent(run)) return;
      _loadError = gardenFailureMessage(failure);
      _canRetry = true;
    } finally {
      if (_isCurrent(run)) {
        _isLoading = false;
        _notify();
      }
    }
  }

  /// Whether [run] is the newest read, on a ViewModel still in use.
  bool _isCurrent(int run) => run == _run && !_disposed;

  void _onGardenChanged() {
    if (!_disposed) refresh();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _gardenRepository.removeListener(_onGardenChanged);
    super.dispose();
  }
}
