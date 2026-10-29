import 'package:flutter/material.dart';

import '../themes/colors.dart';

/// Placeholder for a screen that is not built yet: an icon tile, [title] and
/// "Em breve", in the empty-state layout of the Claude Design screens.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.icon, required this.title});

  final Widget icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(32),
              ),
              alignment: Alignment.center,
              child: IconTheme(
                data: const IconThemeData(color: AppColors.forest, size: 52),
                child: icon,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Em breve',
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
