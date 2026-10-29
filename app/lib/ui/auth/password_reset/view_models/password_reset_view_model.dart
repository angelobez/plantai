import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth/auth_repository.dart';
import '../../../../domain/models/auth_failure.dart';
import '../../auth_failure_message.dart';
import '../../validators.dart';

/// The two steps of "Esqueci a senha".
enum PasswordResetStep {
  /// Which e-mail gets the code.
  email,

  /// The code from the e-mail and the new password.
  code,
}

/// "Esqueci a senha": the e-mail, then the code and a new password, which
/// signs the User in (the router then takes them to the tabs). Also how an
/// account made with Google gets a password.
class PasswordResetViewModel extends ChangeNotifier {
  PasswordResetViewModel({
    required this._authRepository,
    this.resendCooldown = const Duration(seconds: 45),
  });

  final AuthRepository _authRepository;

  /// How long to wait between codes.
  final Duration resendCooldown;

  Timer? _cooldown;
  bool _disposed = false;

  PasswordResetStep _step = PasswordResetStep.email;
  PasswordResetStep get step => _step;

  /// Where the code went; empty until it is sent.
  String _email = '';
  String get email => _email;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  bool _isResending = false;

  int _resendSecondsLeft = 0;

  /// Seconds until "reenviar código" works again; 0 when it does.
  int get resendSecondsLeft => _resendSecondsLeft;

  bool get canResend =>
      _resendSecondsLeft == 0 && !_isResending && !_isSubmitting;

  String? _emailError;
  String? get emailError => _emailError;

  String? _codeError;
  String? get codeError => _codeError;

  String? _passwordError;
  String? get passwordError => _passwordError;

  /// What went wrong with the API, for the whole form.
  String? _error;
  String? get error => _error;

  /// A good news line, such as "Enviamos um código novo."
  String? _notice;
  String? get notice => _notice;

  /// Step 1: asks for the code and, once sent, moves to [PasswordResetStep.code].
  Future<void> requestCode(String email) async {
    _clearMessages();
    _emailError = validateEmail(email);
    if (_emailError != null) {
      _notify();
      return;
    }

    _isSubmitting = true;
    _notify();
    try {
      final trimmed = email.trim();
      await _authRepository.requestPasswordReset(trimmed);
      _email = trimmed;
      _step = PasswordResetStep.code;
      _startCooldown();
    } on AuthFailure catch (failure) {
      _error = authFailureMessage(failure);
    } finally {
      _isSubmitting = false;
      _notify();
    }
  }

  /// Step 2: sets [newPassword] with [code], which signs in.
  Future<void> confirm({
    required String code,
    required String newPassword,
  }) async {
    _clearMessages();
    _codeError = validateCode(code);
    _passwordError = validatePassword(newPassword);
    if (_codeError != null || _passwordError != null) {
      _notify();
      return;
    }

    _isSubmitting = true;
    _notify();
    try {
      await _authRepository.resetPassword(
        email: _email,
        code: code,
        newPassword: newPassword,
      );
    } on AuthFailure catch (failure) {
      _error = authFailureMessage(failure);
    } finally {
      _isSubmitting = false;
      _notify();
    }
  }

  /// Sends another code to [email], once the countdown is over.
  Future<void> resend() async {
    if (!canResend) return;
    _isResending = true;
    _clearMessages();
    _notify();
    try {
      await _authRepository.requestPasswordReset(_email);
      _notice = 'Enviamos um código novo.';
      _startCooldown();
    } on AuthFailure catch (failure) {
      _error = authFailureMessage(failure);
    } finally {
      _isResending = false;
      _notify();
    }
  }

  /// "Corrigir o e-mail": back to [PasswordResetStep.email].
  void editEmail() {
    _clearMessages();
    _step = PasswordResetStep.email;
    _notify();
  }

  void _clearMessages() {
    _emailError = null;
    _codeError = null;
    _passwordError = null;
    _error = null;
    _notice = null;
  }

  void _startCooldown() {
    _cooldown?.cancel();
    _resendSecondsLeft = resendCooldown.inSeconds;
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      _resendSecondsLeft -= 1;
      if (_resendSecondsLeft <= 0) {
        _resendSecondsLeft = 0;
        timer.cancel();
      }
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cooldown?.cancel();
    super.dispose();
  }
}
