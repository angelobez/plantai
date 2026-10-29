import 'package:flutter/foundation.dart';

/// Build-time settings, passed with `--dart-define`.
abstract final class AppConfig {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Where the API lives, such as `http://localhost:3000`.
  ///
  /// Release builds have no default, so a build without
  /// `--dart-define=API_BASE_URL=...` fails on start instead of calling a
  /// guessed address. Debug builds fall back to `http://localhost:3000`, which
  /// reaches the notebook through `adb reverse tcp:3000 tcp:3000`.
  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    if (kDebugMode) return 'http://localhost:3000';
    throw StateError(
      'API_BASE_URL is not set: build with --dart-define=API_BASE_URL=<url>',
    );
  }
}
