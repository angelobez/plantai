import 'package:flutter/material.dart';

import '../../widgets/entry_page.dart';
import '../../widgets/form_message.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/submit_button.dart';
import '../view_models/signup_view_model.dart';

/// "Criar conta": name, e-mail and password. Once the API sends the code,
/// [onCodeSent] goes to the code screen.
class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.viewModel,
    required this.onCodeSent,
  });

  final SignupViewModel viewModel;
  final VoidCallback onCodeSent;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final sent = await widget.viewModel.submit(
      name: _name.text,
      email: _email.text,
      password: _password.text,
    );
    if (sent && mounted) widget.onCodeSent();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final viewModel = widget.viewModel;
        final enabled = !viewModel.isSubmitting;
        return EntryPage(
          title: 'Criar conta',
          fields: [
            LabeledTextField(
              label: 'Nome',
              controller: _name,
              enabled: enabled,
              helperText: 'Nos anúncios, os vizinhos veem só o primeiro nome.',
              errorText: viewModel.nameError,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            LabeledTextField(
              label: 'E-mail',
              controller: _email,
              enabled: enabled,
              errorText: viewModel.emailError,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            LabeledTextField(
              label: 'Senha',
              controller: _password,
              enabled: enabled,
              obscureText: true,
              helperText: 'Pelo menos 8 caracteres.',
              errorText: viewModel.passwordError,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _submit(),
            ),
            FormMessage(error: viewModel.error),
          ],
          actions: [
            SubmitButton(
              label: 'Criar conta',
              isLoading: viewModel.isSubmitting,
              onPressed: _submit,
            ),
          ],
        );
      },
    );
  }
}
