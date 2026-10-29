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

  /// "Esqueci a senha": has the API e-mail a 6-digit code to [email]. It
  /// answers the same whether [email] has an account or not.
  Future<void> requestPasswordReset(String email);

  /// Sets [newPassword] with the [code] e-mailed to [email] and signs in.
  /// The API ends the sessions on other devices.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
}
