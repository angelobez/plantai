import 'package:flutter/material.dart';

import '../themes/colors.dart';

/// "Voltar" as a white circle over a photo, at the top of the screens that
/// open with one (Tela da espécie, Tela da planta, Foto não reconhecida).
class RoundBackButton extends StatelessWidget {
  const RoundBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Voltar',
      onPressed: () => Navigator.of(context).maybePop(),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        foregroundColor: AppColors.ink,
        fixedSize: const Size.square(44),
      ),
      icon: const Icon(Icons.chevron_left, size: 24),
    );
  }
}
