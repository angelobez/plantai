import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The tokens of a signed-in User.
@immutable
class Session {
  const Session({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken);
}

/// Where the [Session] lives: in memory for the `ApiClient` to read on every
/// request, and in `flutter_secure_storage` so it survives closing the app.
///
/// It notifies its listeners whenever the session starts, changes (a refresh)
/// or ends. Only `AuthRepository` and the `ApiClient` touch it; the rest of
/// the app asks `AuthRepository`.
class SessionStore extends ChangeNotifier {
  SessionStore._(this._storage, this._session);

  static const _accessTokenKey = 'session.accessToken';
  static const _refreshTokenKey = 'session.refreshToken';

  /// Reads the session saved by the last run, if any. Call once, at start.
  static Future<SessionStore> load([
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  ]) async {
    final accessToken = await storage.read(key: _accessTokenKey);
    final refreshToken = await storage.read(key: _refreshTokenKey);
    final session = accessToken != null && refreshToken != null
        ? Session(accessToken: accessToken, refreshToken: refreshToken)
        : null;
    return SessionStore._(storage, session);
  }

  final FlutterSecureStorage _storage;
  Session? _session;

  /// The current session; null when nobody is signed in.
  Session? get session => _session;

  Future<void> save(Session session) async {
    await _storage.write(key: _accessTokenKey, value: session.accessToken);
    await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
    _session = session;
    notifyListeners();
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    if (_session == null) return;
    _session = null;
    notifyListeners();
  }
}
