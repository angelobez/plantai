import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';

/// One of the big choices of Foto (and of Limite diário, which looks the
/// same): dark green for the main one, mist for the other. Disabled (faded)
/// while [onTap] is null.
class PhotoActionTile extends StatelessWidget {
  const PhotoActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = primary ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: primary ? AppColors.forest : AppColors.mist,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: primary ? Colors.white : AppColors.forest,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: foreground,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: primary
                                    ? const Color(0xFFDCE9DF)
                                    : AppColors.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
