import 'dart:async';

import 'package:plantai/data/services/location/location_service.dart';

/// Vila Mariana, São Paulo.
const vilaMariana = ApproximatePosition(
  latitude: -23.5874,
  longitude: -46.6345,
);

/// A [LocationService] the test drives: [currentPosition] answers [next]
/// (the User at [vilaMariana] by default) and [suggestNeighborhood] answers
/// [neighborhood]. Records what was asked.
///
/// Set [gate] to hold [currentPosition] until the test completes it.
class FakeLocationService implements LocationService {
  FakeLocationService({
    this.next = const LocationFound(vilaMariana),
    this.neighborhood = 'Vila Mariana',
  });

  /// What the next [currentPosition] answers.
  LocationResult next;

  /// What [suggestNeighborhood] answers.
  String? neighborhood;

  /// When set, [currentPosition] waits for it before answering.
  Completer<void>? gate;

  /// How many times [currentPosition] was called.
  int asked = 0;

  /// The positions [suggestNeighborhood] got.
  final geocoded = <ApproximatePosition>[];

  /// How many times each settings page was opened.
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<LocationResult> currentPosition() async {
    asked++;
    await gate?.future;
    return next;
  }

  @override
  Future<String?> suggestNeighborhood(ApproximatePosition position) async {
    geocoded.add(position);
    return neighborhood;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }
}
