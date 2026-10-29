import 'package:flutter/material.dart';

import '../../../core/themes/colors.dart';
import '../../widgets/code_field.dart';
import '../../widgets/entry_page.dart';
import '../../widgets/form_message.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/resend_code_line.dart';
import '../../widgets/submit_button.dart';
import '../view_models/password_reset_view_model.dart';

/// "Esqueci a senha", in two steps on one screen: the e-mail, then the code
/// and the new password. Not drawn in Claude Design; it follows the code
/// screen and Criar conta.
///
/// Saving signs in, and the router takes the User to the tabs. On the code
/// step, "Voltar" and "Corrigir o e-mail" go back to the e-mail step.
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, required this.viewModel});

  final PasswordResetViewModel viewModel;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  PasswordResetViewModel get _viewModel => widget.viewModel;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    await _viewModel.requestCode(_email.text);
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    await _viewModel.confirm(code: _code.text, newPassword: _password.text);
  }

  void _editEmail() {
    _code.clear();
    _password.clear();
    _viewModel.editEmail();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final onCodeStep = _viewModel.step == PasswordResetStep.code;
        return PopScope(
          canPop: !onCodeStep,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !_viewModel.isSubmitting) _editEmail();
          },
          child: onCodeStep ? _codeStep() : _emailStep(),
        );
      },
    );
  }

  Widget _emailStep() {
    final viewModel = _viewModel;
    return EntryPage(
      title: 'Esqueci a senha',
      subtitle: const Text(
        'Informe o e-mail da sua conta. Mandamos um código para você criar '
        'uma senha nova.',
      ),
      fields: [
        LabeledTextField(
          label: 'E-mail',
          controller: _email,
          enabled: !viewModel.isSubmitting,
          errorText: viewModel.emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _requestCode(),
        ),
        FormMessage(error: viewModel.error),
      ],
      actions: [
        SubmitButton(
          label: 'Enviar código',
          isLoading: viewModel.isSubmitting,
          onPressed: _requestCode,
        ),
      ],
    );
  }

  Widget _codeStep() {
    final viewModel = _viewModel;
    final enabled = !viewModel.isSubmitting;
    return EntryPage(
      title: 'Crie uma senha nova',
      subtitle: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Mandamos um código de 6 dígitos para '),
            TextSpan(
              text: viewModel.email,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const TextSpan(
              text: ', se ele tiver conta no PlantAí. Ele vale por 15 minutos.',
            ),
          ],
        ),
      ),
      fields: [
        CodeField(
          controller: _code,
          enabled: enabled,
          errorText: viewModel.codeError,
          onCompleted: (_) => FocusScope.of(context).nextFocus(),
        ),
        ResendCodeLine(
          secondsLeft: viewModel.resendSecondsLeft,
          canResend: viewModel.canResend,
          onResend: viewModel.resend,
        ),
        LabeledTextField(
          label: 'Senha nova',
          controller: _password,
          enabled: enabled,
          obscureText: true,
          helperText: 'Pelo menos 8 caracteres.',
          errorText: viewModel.passwordError,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _confirm(),
        ),
        FormMessage(error: viewModel.error, notice: viewModel.notice),
      ],
      actions: [
        SubmitButton(
          label: 'Salvar e entrar',
          isLoading: viewModel.isSubmitting,
          onPressed: _confirm,
        ),
        TextButton(
          onPressed: enabled ? _editEmail : null,
          child: const Text('Corrigir o e-mail'),
        ),
      ],
    );
  }
}
