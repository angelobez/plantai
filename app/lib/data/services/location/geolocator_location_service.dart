import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' show Geocoding;
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// [LocationService] over `geolocator` (permission and position) and
/// `geocoding` (the Android geocoder). The manifest has only
/// `ACCESS_COARSE_LOCATION`, so the position comes at low accuracy.
class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({Geocoding? geocoding})
    : _geocoding = geocoding ?? Geocoding();

  final Geocoding _geocoding;

  /// How long to wait for a position before giving up.
  static const _timeLimit = Duration(seconds: 15);

  @override
  Future<LocationResult> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationServiceDisabled();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          return const LocationDenied();
        case LocationPermission.deniedForever:
          return const LocationDeniedForever();
        case LocationPermission.unableToDetermine:
          return const LocationUnavailable();
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: _timeLimit,
        ),
      );
      return LocationFound(
        ApproximatePosition(
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on LocationServiceDisabledException {
      return const LocationServiceDisabled();
    } on PermissionDeniedException {
      return const LocationDenied();
    } on Object catch (error) {
      debugPrint('Location failed: $error');
      return const LocationUnavailable();
    }
  }

  @override
  Future<String?> suggestNeighborhood(ApproximatePosition position) async {
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final neighborhood = placemarks.firstOrNull?.subLocality?.trim();
      return neighborhood == null || neighborhood.isEmpty ? null : neighborhood;
    } on Object catch (error) {
      debugPrint('Geocoding failed: $error');
      return null;
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
