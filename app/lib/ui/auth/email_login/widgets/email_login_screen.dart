import 'package:flutter/material.dart';

import '../../../core/themes/colors.dart';
import '../../widgets/entry_page.dart';
import '../../widgets/form_message.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/submit_button.dart';
import '../view_models/email_login_view_model.dart';

/// "Entrar com e-mail": e-mail and password, "Esqueci a senha" under the
/// password and "Criar conta" under the button.
///
/// Signing in needs no callback (the router sees the session). An unconfirmed
/// e-mail calls [onVerifyEmail], to go to the code screen.
class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({
    super.key,
    required this.viewModel,
    required this.onVerifyEmail,
    required this.onSignup,
    this.onForgotPassword,
  });

  final EmailLoginViewModel viewModel;
  final VoidCallback onVerifyEmail;

  /// "Ainda não tem conta? Criar conta".
  final VoidCallback onSignup;

  /// "Esqueci a senha"; null shows "em breve".
  final VoidCallback? onForgotPassword;

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await _follow(
      widget.viewModel.submit(email: _email.text, password: _password.text),
    );
  }

  /// "Tentar de novo", after a failure for lack of connection.
  Future<void> _retry() => _follow(widget.viewModel.retry());

  Future<void> _follow(Future<EmailLoginResult> attempt) async {
    if (await attempt == EmailLoginResult.verifyEmail && mounted) {
      widget.onVerifyEmail();
    }
  }

  void _forgotPassword() {
    final onForgotPassword = widget.onForgotPassword;
    if (onForgotPassword != null) {
      onForgotPassword();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Esqueci a senha: em breve')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final enabled = !viewModel.isSubmitting;
        return EntryPage(
          title: 'Entrar com e-mail',
          fields: [
            LabeledTextField(
              label: 'E-mail',
              controller: _email,
              enabled: enabled,
              errorText: viewModel.emailError,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledTextField(
                  label: 'Senha',
                  controller: _password,
                  enabled: enabled,
                  obscureText: true,
                  errorText: viewModel.passwordError,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: enabled ? _forgotPassword : null,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: AppColors.forest,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Esqueci a senha'),
                  ),
                ),
              ],
            ),
            FormMessage(
              error: viewModel.error,
              onRetry: viewModel.canRetry ? _retry : null,
            ),
          ],
          actions: [
            SubmitButton(
              label: 'Entrar',
              isLoading: viewModel.isSubmitting,
              onPressed: _submit,
            ),
            TextButton(
              onPressed: enabled ? widget.onSignup : null,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.ink,
              ),
              child: const Text.rich(
                TextSpan(
                  text: 'Ainda não tem conta? ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  children: [
                    TextSpan(
                      text: 'Criar conta',
                      style: TextStyle(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
