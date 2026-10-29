import 'package:flutter/material.dart';

import '../../../core/themes/colors.dart';
import '../../../core/widgets/leaf_icon.dart';
import '../../../core/widgets/plantai_logo.dart';

/// The first screen without a session: the logo, the tagline and the two ways
/// in. "Entrar com Google" arrives with its own ticket; until then it says
/// "em breve".
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.onEmail, this.onGoogle});

  /// "Entrar com e-mail".
  final VoidCallback onEmail;

  /// "Entrar com Google"; null shows "em breve".
  final VoidCallback? onGoogle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(child: _Brand()),
              OutlinedButton.icon(
                onPressed: onGoogle ?? () => _comingSoon(context),
                icon: const _GoogleMark(),
                label: const Text('Entrar com Google'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onEmail,
                icon: const Icon(Icons.mail_outline, size: 20),
                label: const Text('Entrar com e-mail'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Entrar com Google: em breve')),
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
  const _GoogleMark();

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
