import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In could not give an ID token (misconfigured client, no Google
/// account support on the phone, and so on). Canceling is not one of these.
class GoogleIdTokenUnavailable implements Exception {
  const GoogleIdTokenUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'GoogleIdTokenUnavailable: $reason';
}

/// Asks Google for an ID token for the API (`POST /v1/auth/google`).
abstract interface class GoogleIdTokens {
  /// Shows Google's account picker and returns the chosen account's ID token,
  /// or null if the User cancels. Throws [GoogleIdTokenUnavailable] otherwise.
  Future<String?> request();
}

/// [GoogleIdTokens] through the `google_sign_in` plugin (Credential Manager on
/// Android). The token is issued for [serverClientId], the Web client the API
/// checks as the audience; null when the build did not get one.
class GoogleSignInIdTokens implements GoogleIdTokens {
  GoogleSignInIdTokens({required this._serverClientId, GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final String? _serverClientId;
  final GoogleSignIn _signIn;

  /// `initialize` must run exactly once, before the first `authenticate`.
  Future<void>? _initialized;

  @override
  Future<String?> request() async {
    final serverClientId = _serverClientId;
    if (serverClientId == null) {
      throw const GoogleIdTokenUnavailable(
        'GOOGLE_SERVER_CLIENT_ID is not set: build with '
        '--dart-define=GOOGLE_SERVER_CLIENT_ID=<Web client ID>',
      );
    }
    try {
      await (_initialized ??= _signIn
          .initialize(serverClientId: serverClientId)
          .catchError((Object error) {
            _initialized = null; // Try again on the next tap.
            throw error;
          }));
      final account = await _signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const GoogleIdTokenUnavailable('Google returned no ID token');
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          return null;
        default:
          // Shows up in `flutter logs`, to tell a SHA-1 or client ID problem.
          debugPrint(
            'Google Sign-In failed: ${error.code} ${error.description}',
          );
          throw GoogleIdTokenUnavailable('${error.code}');
      }
    }
  }
}
