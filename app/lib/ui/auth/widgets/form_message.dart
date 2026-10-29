import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';

/// A line about the whole form: an [error] from the API (in red) or a
/// [notice] (in green). Shows nothing when both are null.
///
/// With [onRetry], the error also offers "Tentar de novo": an entry screen
/// passes it when the last attempt failed for lack of connection
/// (`RetryWhenOffline.canRetry`).
class FormMessage extends StatelessWidget {
  const FormMessage({super.key, this.error, this.notice, this.onRetry});

  final String? error;
  final String? notice;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error ?? notice;
    if (message == null) return const SizedBox.shrink();
    final isError = error != null;
    final onRetry = isError ? this.onRetry : null;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFBEDEA) : AppColors.mist,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isError ? AppColors.danger : AppColors.forest,
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('Tentar de novo'),
              ),
          ],
        ),
      ),
    );
  }
}
