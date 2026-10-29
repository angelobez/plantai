import 'package:flutter/material.dart';

import '../../../core/themes/colors.dart';
import '../../../core/widgets/leaf_icon.dart';
import '../../../core/widgets/plantai_logo.dart';
import '../../widgets/form_message.dart';
import '../view_models/login_view_model.dart';

/// The first screen without a session: the logo, the tagline and the two ways
/// in. "Entrar com Google" signs in right here; the router then leaves for
/// the tabs.
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.viewModel,
    required this.onEmail,
  });

  /// The "G" inside "Entrar com Google", for tests to find the button by.
  static const googleButtonKey = Key('login.google');

  final LoginViewModel viewModel;

  /// "Entrar com e-mail".
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) {
              final isLoading = viewModel.isSigningInWithGoogle;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: _Brand()),
                  if (viewModel.error case final error?) ...[
                    FormMessage(
                      error: error,
                      onRetry: viewModel.canRetry ? viewModel.retry : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : viewModel.signInWithGoogle,
                    icon: isLoading
                        ? const SizedBox.square(
                            key: googleButtonKey,
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const _GoogleMark(key: googleButtonKey),
                    label: const Text('Entrar com Google'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: isLoading ? null : onEmail,
                    icon: const Icon(Icons.mail_outline, size: 20),
                    label: const Text('Entrar com e-mail'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: const LeafIcon(size: 52, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const PlantaiLogo(fontSize: 36, showLeaf: false),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: const Text(
                'Descubra que planta é essa, aprenda a cuidar dela e doe '
                'mudas para os vizinhos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round "G" of the Claude Design screen (not Google's colored logo).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.inkMuted, width: 1.5),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
