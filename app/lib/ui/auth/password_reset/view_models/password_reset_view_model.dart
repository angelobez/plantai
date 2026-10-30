import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth/auth_repository.dart';
import '../../../../domain/models/auth_failure.dart';
import '../../auth_failure_message.dart';
import '../../retry_when_offline.dart';
import '../../resend_countdown.dart';
import '../../validators.dart';
import '../../../core/view_models/safe_notify.dart';

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
class PasswordResetViewModel extends ChangeNotifier
    with RetryWhenOffline<void>, SafeNotify {
  PasswordResetViewModel({
    required this._authRepository,
    this.resendCooldown = const Duration(seconds: 45),
  });

  final AuthRepository _authRepository;

  /// How long to wait between codes.
  final Duration resendCooldown;

  late final _countdown = ResendCountdown(
    duration: resendCooldown,
    onTick: notify,
  );

  PasswordResetStep _step = PasswordResetStep.email;
  PasswordResetStep get step => _step;

  /// Where the code went; empty until it is sent.
  String _email = '';
  String get email => _email;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  bool _isResending = false;

  /// Seconds until "reenviar código" works again; 0 when it does.
  int get resendSecondsLeft => _countdown.secondsLeft;

  bool get canResend =>
      resendSecondsLeft == 0 && !_isResending && !_isSubmitting;

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
      notify();
      return;
    }

    _isSubmitting = true;
    notify();
    try {
      final trimmed = email.trim();
      await _authRepository.requestPasswordReset(trimmed);
      _email = trimmed;
      _step = PasswordResetStep.code;
      _countdown.restart();
    } on AuthFailure catch (failure) {
      offerRetry(failure, () => requestCode(email));
      _error = authFailureMessage(failure);
    } finally {
      _isSubmitting = false;
      notify();
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
      notify();
      return;
    }

    _isSubmitting = true;
    notify();
    try {
      await _authRepository.resetPassword(
        email: _email,
        code: code,
        newPassword: newPassword,
      );
    } on AuthFailure catch (failure) {
      offerRetry(failure, () => confirm(code: code, newPassword: newPassword));
      _error = authFailureMessage(failure);
    } finally {
      _isSubmitting = false;
      notify();
    }
  }

  /// Sends another code to [email], once the countdown is over.
  Future<void> resend() async {
    if (!canResend) return;
    _isResending = true;
    _clearMessages();
    notify();
    try {
      await _authRepository.requestPasswordReset(_email);
      _notice = 'Enviamos um código novo.';
      _countdown.restart();
    } on AuthFailure catch (failure) {
      offerRetry(failure, resend);
      _error = authFailureMessage(failure);
    } finally {
      _isResending = false;
      notify();
    }
  }

  /// "Corrigir o e-mail": back to [PasswordResetStep.email].
  void editEmail() {
    _clearMessages();
    _step = PasswordResetStep.email;
    notify();
  }

  void _clearMessages() {
    _emailError = null;
    _codeError = null;
    _passwordError = null;
    _error = null;
    _notice = null;
    clearRetry();
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }
}
