import 'package:flutter/foundation.dart';

import '../../../data/repositories/listing/listing_repository.dart';
import '../../../data/services/api/models/listing.dart';
import '../../../data/services/location/location_service.dart';
import '../../../domain/models/listing_failure.dart';
import '../../core/view_models/safe_notify.dart';
import '../../donation_profile/view_models/donation_profile_view_model.dart'
    show LocationProblem;
import '../listing_failure_message.dart';

/// Detalhe do anúncio: one listing, with the distance from the searcher.
///
/// The distance is measured from [from] when given (the position the Por
/// perto list was read from); otherwise [load] asks for the location, and
/// without one shows [locationProblem]. A listing that is no longer active
/// still shows, with [isAvailable] false.
class ListingDetailViewModel extends ChangeNotifier with SafeNotify {
  ListingDetailViewModel({
    required this._listingRepository,
    required this._locationService,
    required this.listingId,
    ApproximatePosition? from,
    DateTime Function() clock = DateTime.now,
  }) : _position = from,
       _now = clock;

  final ListingRepository _listingRepository;
  final LocationService _locationService;
  final DateTime Function() _now;

  final String listingId;

  /// The instant "anunciado há X dias" counts until.
  DateTime get now => _now();

  ApproximatePosition? _position;

  /// Null until it is read.
  ListingDetail? _listing;
  ListingDetail? get listing => _listing;

  /// Whether the listing is still active, so "Tenho interesse" makes sense;
  /// otherwise the screen says it is no longer available.
  bool get isAvailable => _listing?.status == ListingStatus.active;

  /// Why there is no location, if that is what stopped the read.
  LocationProblem? _locationProblem;
  LocationProblem? get locationProblem => _locationProblem;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Why the last read failed.
  String? _loadError;
  String? get loadError => _loadError;

  /// Whether reading again makes sense for [loadError].
  bool _canRetry = false;
  bool get canRetry => _canRetry;

  /// Reads the listing, asking for the location first when there is no
  /// position yet.
  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    _locationProblem = null;
    notify();
    try {
      final position = _position ?? await _locate();
      if (position == null || isDisposed) return;
      _position = position;
      _listing = await _listingRepository.detail(listingId, from: position);
    } on ListingFailure catch (failure) {
      _loadError = listingFailureMessage(failure);
      _canRetry = failure != ListingFailure.notFound;
    } finally {
      _isLoading = false;
      notify();
    }
  }

  Future<ApproximatePosition?> _locate() async {
    switch (await _locationService.currentPosition()) {
      case LocationFound(:final position):
        return position;
      case LocationDenied():
        _locationProblem = LocationProblem.denied;
      case LocationDeniedForever():
        _locationProblem = LocationProblem.deniedForever;
      case LocationServiceDisabled():
        _locationProblem = LocationProblem.serviceDisabled;
      case LocationUnavailable():
        _locationProblem = LocationProblem.unavailable;
    }
    return null;
  }

  /// Opens the Android settings that fix the [locationProblem].
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
}
