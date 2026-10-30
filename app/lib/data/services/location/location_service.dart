/// A point in decimal degrees, as the phone found it: approximate (the app
/// only asks for the coarse location).
class ApproximatePosition {
  const ApproximatePosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is ApproximatePosition &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'ApproximatePosition($latitude, $longitude)';
}

/// What came out of [LocationService.currentPosition].
sealed class LocationResult {
  const LocationResult();
}

/// The phone found the User at [position].
final class LocationFound extends LocationResult {
  const LocationFound(this.position);

  final ApproximatePosition position;
}

/// The User refused the permission; asking again may work.
final class LocationDenied extends LocationResult {
  const LocationDenied();
}

/// The User refused the permission for good: only the Android settings can
/// give it back ([LocationService.openAppSettings]).
final class LocationDeniedForever extends LocationResult {
  const LocationDeniedForever();
}

/// The phone's location is turned off ([LocationService.openLocationSettings]).
final class LocationServiceDisabled extends LocationResult {
  const LocationServiceDisabled();
}

/// The position could not be found (a timeout or a plugin error).
final class LocationUnavailable extends LocationResult {
  const LocationUnavailable();
}

/// The port to the phone's location and geocoder. The real one is
/// `GeolocatorLocationService`; tests use a fake that answers what the test
/// says.
///
/// The (coarse) permission is asked only by [currentPosition], never before.
abstract class LocationService {
  /// The approximate position, asking for the permission when needed.
  Future<LocationResult> currentPosition();

  /// The neighborhood the geocoder finds at [position], or null when it
  /// finds none or fails. Only a suggestion: the User may correct it.
  Future<String?> suggestNeighborhood(ApproximatePosition position);

  /// Opens this app's page in the Android settings (to give back a
  /// permission refused for good); whether it opened.
  Future<bool> openAppSettings();

  /// Opens the Android location settings (to turn the location on); whether
  /// it opened.
  Future<bool> openLocationSettings();
}
