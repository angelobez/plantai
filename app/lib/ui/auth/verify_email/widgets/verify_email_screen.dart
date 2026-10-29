import 'package:flutter/material.dart';

import '../../../core/themes/colors.dart';
import '../../widgets/code_field.dart';
import '../../widgets/entry_page.dart';
import '../../widgets/form_message.dart';
import '../../widgets/submit_button.dart';
import '../view_models/verify_email_view_model.dart';

/// "Confirme seu e-mail": the 6-digit code, "reenviar código" and the way
/// back to fix the e-mail. A right code signs in, and the router takes the
/// User to the tabs.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.viewModel});

  final VerifyEmailViewModel viewModel;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() => widget.viewModel.submit(_code.text);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        return EntryPage(
          title: 'Confirme seu e-mail',
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
                const TextSpan(text: '. Ele vale por 15 minutos.'),
              ],
            ),
          ),
          fields: [
            CodeField(
              controller: _code,
              enabled: !viewModel.isSubmitting,
              errorText: viewModel.codeError,
              onCompleted: (_) => _submit(),
            ),
            _ResendLine(viewModel: viewModel),
            FormMessage(error: viewModel.error, notice: viewModel.notice),
          ],
          actions: [
            SubmitButton(
              label: 'Confirmar',
              isLoading: viewModel.isSubmitting,
              onPressed: _submit,
            ),
            TextButton(
              onPressed: viewModel.isSubmitting
                  ? null
                  : () => Navigator.of(context).maybePop(),
              child: const Text('Corrigir o e-mail'),
            ),
          ],
        );
      },
    );
  }
}

class _ResendLine extends StatelessWidget {
  const _ResendLine({required this.viewModel});

  final VerifyEmailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final seconds = viewModel.resendSecondsLeft;
    final countdown =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Não chegou? Veja o spam ou ',
          style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
        ),
        if (seconds > 0)
          Text(
            'reenvie em $countdown',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.inkMuted,
            ),
          )
        else
          TextButton(
            onPressed: viewModel.canResend ? viewModel.resend : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 44),
            ),
            child: const Text('reenvie o código'),
          ),
      ],
    );
  }
}
