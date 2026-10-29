import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth/auth_repository.dart';
import '../../../../domain/models/auth_failure.dart';
import '../../auth_failure_message.dart';
import '../../validators.dart';

/// "Criar conta": checks name, e-mail and password, then has the API send
/// the code. On success the screen goes to the code screen.
class SignupViewModel extends ChangeNotifier {
  SignupViewModel({required this._authRepository});

  final AuthRepository _authRepository;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _nameError;
  String? get nameError => _nameError;

  String? _emailError;
  String? get emailError => _emailError;

  String? _passwordError;
  String? get passwordError => _passwordError;

  /// What went wrong with the API, for the whole form.
  String? _error;
  String? get error => _error;

  /// Whether the code was sent.
  Future<bool> submit({
    required String name,
    required String email,
    required String password,
  }) async {
    _nameError = validateName(name);
    _emailError = validateEmail(email);
    _passwordError = validatePassword(password);
    _error = null;
    if (_nameError != null || _emailError != null || _passwordError != null) {
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    notifyListeners();
    try {
      await _authRepository.signUp(
        name: name.trim(),
        email: email.trim(),
        password: password,
      );
      return true;
    } on AuthFailure catch (failure) {
      _error = authFailureMessage(failure);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
