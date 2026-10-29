import 'package:flutter/foundation.dart';

/// The source of truth about "is someone signed in", and every way in.
///
/// It notifies its listeners when [isSignedIn] changes; the router listens to
/// send the User to Login or to the tabs. Every method throws an `AuthFailure`
/// when it fails.
abstract class AuthRepository extends ChangeNotifier {
  /// Whether there is a saved session. On start, a saved refresh token is
  /// enough: the first protected call renews the session if it needs to.
  bool get isSignedIn;

  /// The e-mail waiting for a code (after [signUp]); null when none is.
  String? get pendingEmail;

  /// Creates the account (or updates the unconfirmed one) and has the API
  /// e-mail a 6-digit code to [email], which becomes [pendingEmail].
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// Repeats the request that sent the last code, so the API sends a new one.
  Future<void> resendCode();

  /// Confirms [pendingEmail] with [code] and signs the User in.
  Future<void> verifyEmail(String code);

  /// Signs in with e-mail and password. When the e-mail was never confirmed
  /// it throws `AuthFailure.emailNotVerified`: the API has sent a new code,
  /// and [email] becomes [pendingEmail].
  Future<void> logIn({required String email, required String password});

  /// Ends the session: asks the API to revoke the refresh token and forgets
  /// the tokens. The tokens are forgotten even when the API cannot be reached,
  /// so this never throws.
  Future<void> signOut();

  /// Shows Google's account picker and signs in with the chosen account. If
  /// the User cancels, it returns without a session and without a failure.
  Future<void> signInWithGoogle();
}
