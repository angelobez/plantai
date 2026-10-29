import 'dart:async';

import 'package:plantai/data/repositories/auth/auth_repository.dart';
import 'package:plantai/domain/models/auth_failure.dart';

/// An [AuthRepository] the test drives: it records the calls and answers
/// with [failure] (when set) or success.
///
/// Set [gate] to hold every call until the test completes it, to check what
/// a screen shows while it waits.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({this._signedIn = false, this._pendingEmail});

  bool _signedIn;
  String? _pendingEmail;

  /// Thrown by the next calls, until set back to null.
  AuthFailure? failure;

  /// When set, calls wait for it before answering.
  Completer<void>? gate;

  /// Every call, such as `signUp(marina@email.com)` or `verifyEmail(123456)`.
  final calls = <String>[];

  @override
  bool get isSignedIn => _signedIn;

  @override
  String? get pendingEmail => _pendingEmail;

  /// Starts or ends the session, as the API would, and notifies.
  void setSignedIn(bool signedIn) {
    _signedIn = signedIn;
    notifyListeners();
  }

  Future<void> _answer(String call) async {
    calls.add(call);
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _answer('signUp($name, $email, $password)');
    _pendingEmail = email;
  }

  @override
  Future<void> resendCode() => _answer('resendCode()');

  @override
  Future<void> verifyEmail(String code) async {
    await _answer('verifyEmail($code)');
    _pendingEmail = null;
    setSignedIn(true);
  }

  /// Fails with [failure]; `emailNotVerified` leaves [email] waiting for the
  /// code, as the real one does.
  @override
  Future<void> logIn({required String email, required String password}) async {
    try {
      await _answer('logIn($email, $password)');
    } on AuthFailure catch (failure) {
      if (failure == AuthFailure.emailNotVerified) _pendingEmail = email;
      rethrow;
    }
    setSignedIn(true);
  }

  /// Records the call and ends the session, even when [failure] is set: the
  /// real one forgets the tokens whatever the API answers.
  @override
  Future<void> signOut() async {
    calls.add('signOut()');
    await gate?.future;
    setSignedIn(false);
  }
}
