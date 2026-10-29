import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth/auth_repository.dart';
import '../../../../domain/models/auth_failure.dart';
import '../../auth_failure_message.dart';
import '../../retry_when_offline.dart';

/// Login: "Entrar com Google". On success the router leaves for the tabs;
/// canceling the account picker just stays here, with no message.
class LoginViewModel extends ChangeNotifier with RetryWhenOffline<void> {
  LoginViewModel({required this._authRepository});

  final AuthRepository _authRepository;

  bool _isSigningInWithGoogle = false;
  bool get isSigningInWithGoogle => _isSigningInWithGoogle;

  String? _error;
  String? get error => _error;

  /// Signing in leaves Login, which disposes this before the call returns.
  bool _disposed = false;

  Future<void> signInWithGoogle() async {
    if (_isSigningInWithGoogle) return;
    _isSigningInWithGoogle = true;
    _error = null;
    clearRetry();
    notifyListeners();
    try {
      await _authRepository.signInWithGoogle();
    } on AuthFailure catch (failure) {
      offerRetry(failure, signInWithGoogle);
      _error = switch (failure) {
        // Here it means Google's token was refused, not a wrong password.
        AuthFailure.invalidCredentials => authFailureMessage(
          AuthFailure.unknown,
        ),
        _ => authFailureMessage(failure),
      };
    } finally {
      _isSigningInWithGoogle = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
