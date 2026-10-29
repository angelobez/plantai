import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth/auth_repository.dart';
import '../../../../domain/models/auth_failure.dart';
import '../../auth_failure_message.dart';
import '../../validators.dart';

/// "Confirme seu e-mail": takes the 6-digit code and asks for another one.
///
/// A right code signs the User in; the router then leaves the entry screens,
/// so there is nothing to do here on success.
class VerifyEmailViewModel extends ChangeNotifier {
  VerifyEmailViewModel({
    required this._authRepository,
    this.resendCooldown = const Duration(seconds: 45),
  }) {
    _startCooldown();
  }

  final AuthRepository _authRepository;

  /// How long to wait between codes; the first one was just sent.
  final Duration resendCooldown;

  Timer? _cooldown;
  bool _disposed = false;

  /// Where the code went.
  String get email => _authRepository.pendingEmail ?? '';

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  bool _isResending = false;

  int _resendSecondsLeft = 0;

  /// Seconds until "reenviar código" works again; 0 when it does.
  int get resendSecondsLeft => _resendSecondsLeft;

  bool get canResend =>
      _resendSecondsLeft == 0 && !_isResending && !_isSubmitting;

  String? _codeError;
  String? get codeError => _codeError;

  String? _error;
  String? get error => _error;

  /// A good news line, such as "Enviamos um código novo."
  String? _notice;
  String? get notice => _notice;

  Future<void> submit(String code) async {
    _codeError = validateCode(code);
    _error = null;
    _notice = null;
    if (_codeError != null) {
      _notify();
      return;
    }

    _isSubmitting = true;
    _notify();
    try {
      await _authRepository.verifyEmail(code);
    } on AuthFailure catch (failure) {
      _error = authFailureMessage(failure);
    } finally {
      _isSubmitting = false;
      _notify();
    }
  }

  Future<void> resend() async {
    if (!canResend) return;
    _isResending = true;
    _error = null;
    _notice = null;
    _notify();
    try {
      await _authRepository.resendCode();
      _notice = 'Enviamos um código novo.';
      _startCooldown();
    } on AuthFailure catch (failure) {
      _error = authFailureMessage(failure);
    } finally {
      _isResending = false;
      _notify();
    }
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
