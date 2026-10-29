import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/core/themes/colors.dart';
import 'package:plantai/ui/core/themes/theme.dart';

void main() {
  final theme = AppTheme.light;

  test('uses the Claude Design palette on a white background', () {
    expect(AppColors.sage, const Color(0xFFA9C9AE));
    expect(AppColors.forest, const Color(0xFF3F6B4A));
    expect(AppColors.mist, const Color(0xFFEEF4EF));
    expect(AppColors.ink, const Color(0xFF1F2A22));
    expect(AppColors.inkMuted, const Color(0xFF5B665E));

    expect(theme.colorScheme.primary, AppColors.forest);
    expect(theme.colorScheme.onSurface, AppColors.ink);
    expect(theme.colorScheme.onSurfaceVariant, AppColors.inkMuted);
    expect(theme.scaffoldBackgroundColor, Colors.white);
    expect(theme.colorScheme.surface, Colors.white);
  });

  test('sets Manrope as the font of every text style', () {
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Manrope');
    expect(theme.textTheme.titleLarge?.fontFamily, 'Manrope');
    expect(theme.textTheme.labelLarge?.fontFamily, 'Manrope');
  });

  test('main buttons are dark green pills', () {
    final style = theme.filledButtonTheme.style!;

    expect(style.backgroundColor?.resolve({}), AppColors.forest);
    expect(style.foregroundColor?.resolve({}), Colors.white);
    expect(style.shape?.resolve({}), isA<StadiumBorder>());
  });
}
