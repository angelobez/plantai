import 'package:flutter/foundation.dart';

import '../../../data/repositories/listing/listing_repository.dart';
import '../../../data/services/api/models/listing.dart';
import '../../../data/services/location/location_service.dart';
import '../../../domain/models/listing_failure.dart';
import '../../core/view_models/safe_notify.dart';
import '../../donation_profile/view_models/donation_profile_view_model.dart'
    show LocationProblem;
import '../listing_failure_message.dart';

/// Mudas por perto: the active listings of other Users within 30 km of the
/// phone's approximate location, nearest first.
///
/// [load] and [refresh] (pull to refresh) ask for the location each time,
/// then read the first page; [loadMore] reads the next page, from the same
/// position, while the last page was full. Without a location the list
/// gives way to [locationProblem]. Only the newest read counts: an older
/// answer that comes late is dropped.
class NearbyViewModel extends ChangeNotifier with SafeNotify {
  NearbyViewModel({
    required this._listingRepository,
    required this._locationService,
  });

  final ListingRepository _listingRepository;
  final LocationService _locationService;

  /// Null until the first page comes (and again while [locationProblem]).
  List<NearbyListing>? _listings;
  List<NearbyListing>? get listings => _listings;

  /// Whether the list was read and there is no listing within 30 km.
  bool get isEmpty => _listings?.isEmpty ?? false;

  /// The position the list was read from; the detail measures from it too.
  ApproximatePosition? _position;
  ApproximatePosition? get position => _position;

  /// Why there is no location, if that is what stopped the list.
  LocationProblem? _locationProblem;
  LocationProblem? get locationProblem => _locationProblem;

  /// True while the first read (or the one after an error) is running.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Why the last read of the first page failed.
  String? _loadError;
  String? get loadError => _loadError;

  /// Whether reading again makes sense for [loadError].
  bool _canRetry = false;
  bool get canRetry => _canRetry;

  /// Whether the last page was full, so there may be another one.
  bool _hasMore = false;
  bool get hasMore => _hasMore;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  /// Why the last [loadMore] failed; the list stays, with a retry at its end.
  String? _loadMoreError;
  String? get loadMoreError => _loadMoreError;

  int _page = 0;
  int _run = 0;

  /// Asks for the location and reads the first page, showing the loading
  /// state.
  Future<void> load() => _read(showLoading: true);

  /// Asks for the location again and reads the first page, keeping the
  /// current list on screen.
  Future<void> refresh() => _read(showLoading: _listings == null);

  Future<void> _read({required bool showLoading}) async {
    final run = ++_run;
    _isLoading = showLoading;
    if (showLoading) {
      _loadError = null;
      _locationProblem = null;
    }
    notify();
    try {
      final result = await _locationService.currentPosition();
      if (!_isCurrent(run)) return;
      final ApproximatePosition position;
      switch (result) {
        case LocationFound():
          position = result.position;
        case LocationDenied():
          return _stopAt(LocationProblem.denied);
        case LocationDeniedForever():
          return _stopAt(LocationProblem.deniedForever);
        case LocationServiceDisabled():
          return _stopAt(LocationProblem.serviceDisabled);
        case LocationUnavailable():
          return _stopAt(LocationProblem.unavailable);
      }
      final listings = await _listingRepository.nearby(from: position);
      if (!_isCurrent(run)) return;
      _position = position;
      _listings = listings;
      _page = 1;
      _hasMore = listings.length >= nearbyPageSize;
      _locationProblem = null;
      _loadError = null;
      _loadMoreError = null;
      _canRetry = false;
    } on ListingFailure catch (failure) {
      if (!_isCurrent(run)) return;
      _locationProblem = null;
      _loadError = listingFailureMessage(failure);
      _canRetry = true;
    } finally {
      if (_isCurrent(run)) {
        _isLoading = false;
        notify();
      }
    }
  }

  /// Reads the next page, when there may be one and none is on its way.
  Future<void> loadMore() async {
    final position = _position;
    final current = _listings;
    if (!_hasMore || _isLoadingMore || position == null || current == null) {
      return;
    }
    final run = _run;
    _isLoadingMore = true;
    _loadMoreError = null;
    notify();
    try {
      final next = await _listingRepository.nearby(
        from: position,
        page: _page + 1,
      );
      if (!_isCurrent(run)) return;
      _listings = [...current, ...next];
      _page++;
      _hasMore = next.length >= nearbyPageSize;
    } on ListingFailure catch (failure) {
      if (!_isCurrent(run)) return;
      _loadMoreError = listingFailureMessage(failure);
    } finally {
      if (!isDisposed) {
        _isLoadingMore = false;
        notify();
      }
    }
  }

  /// Opens the Android settings that fix the [locationProblem]: the app's
  /// permissions, or the location switch.
  Future<void> openSettings() async {
    switch (_locationProblem) {
      case LocationProblem.deniedForever:
        await _locationService.openAppSettings();
      case LocationProblem.serviceDisabled:
        await _locationService.openLocationSettings();
      case LocationProblem.denied || LocationProblem.unavailable || null:
        break;
    }
  }

  /// Without a location there is no list: the screen explains [problem].
  void _stopAt(LocationProblem problem) {
    _locationProblem = problem;
    _listings = null;
    _hasMore = false;
    _loadError = null;
  }

  bool _isCurrent(int run) => run == _run && !isDisposed;
}
