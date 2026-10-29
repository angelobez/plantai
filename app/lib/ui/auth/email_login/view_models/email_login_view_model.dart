import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth/auth_repository.dart';
import '../../../../domain/models/auth_failure.dart';
import '../../auth_failure_message.dart';
import '../../retry_when_offline.dart';
import '../../validators.dart';

/// Where "Entrar" leads.
enum EmailLoginResult {
  /// In: the router takes the User to the tabs.
  signedIn,

  /// The e-mail was never confirmed; the API sent a new code, so the screen
  /// goes to the code screen.
  verifyEmail,

  /// Stays, showing the field errors or [EmailLoginViewModel.error].
  failed,
}

/// "Entrar com e-mail": checks e-mail and password, then signs in.
class EmailLoginViewModel extends ChangeNotifier
    with RetryWhenOffline<EmailLoginResult> {
  EmailLoginViewModel({required this._authRepository});

  final AuthRepository _authRepository;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _emailError;
  String? get emailError => _emailError;

  String? _passwordError;
  String? get passwordError => _passwordError;

  /// What went wrong with the API, for the whole form.
  String? _error;
  String? get error => _error;

  Future<EmailLoginResult> submit({
    required String email,
    required String password,
  }) async {
    _emailError = validateEmail(email);
    // Only "not empty": the 8-character rule is for new passwords, and a
    // shorter one is just a wrong one.
    _passwordError = password.isEmpty ? 'Informe a sua senha.' : null;
    _error = null;
    clearRetry();
    if (_emailError != null || _passwordError != null) {
      notifyListeners();
      return EmailLoginResult.failed;
    }

    _isSubmitting = true;
    notifyListeners();
    try {
      await _authRepository.logIn(email: email.trim(), password: password);
      return EmailLoginResult.signedIn;
    } on AuthFailure catch (failure) {
      if (failure == AuthFailure.emailNotVerified) {
        return EmailLoginResult.verifyEmail;
      }
      offerRetry(failure, () => submit(email: email, password: password));
      _error = authFailureMessage(failure);
      return EmailLoginResult.failed;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
