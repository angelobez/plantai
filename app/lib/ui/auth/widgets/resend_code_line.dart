import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';

/// "Não chegou? Veja o spam ou reenvie o código", with the countdown of
/// [secondsLeft] (as `m:ss`) until [onResend] works again.
class ResendCodeLine extends StatelessWidget {
  const ResendCodeLine({
    super.key,
    required this.secondsLeft,
    required this.canResend,
    required this.onResend,
  });

  final int secondsLeft;
  final bool canResend;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final countdown =
        '${secondsLeft ~/ 60}:${(secondsLeft % 60).toString().padLeft(2, '0')}';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Não chegou? Veja o spam ou ',
          style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
        ),
        if (secondsLeft > 0)
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
            onPressed: canResend ? onResend : null,
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
