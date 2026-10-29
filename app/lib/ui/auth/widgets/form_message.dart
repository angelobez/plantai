import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';

/// A line about the whole form: an [error] from the API (in red) or a
/// [notice] (in green). Shows nothing when both are null.
class FormMessage extends StatelessWidget {
  const FormMessage({super.key, this.error, this.notice});

  final String? error;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final message = error ?? notice;
    if (message == null) return const SizedBox.shrink();
    final isError = error != null;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFBEDEA) : AppColors.mist,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isError ? AppColors.danger : AppColors.forest,
          ),
        ),
      ),
    );
  }
}
