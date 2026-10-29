import 'package:flutter/material.dart';

import 'colors.dart';

/// The app's [ThemeData]: white background, the Claude Design greens, Manrope
/// (bundled in `assets/fonts`) and dark green pill buttons.
abstract final class AppTheme {
  static const fontFamily = 'Manrope';

  static const _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.forest,
    onPrimary: Colors.white,
    primaryContainer: AppColors.sage,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.sage,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.mist,
    onSecondaryContainer: AppColors.ink,
    error: AppColors.danger,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: AppColors.mist,
    surfaceContainer: AppColors.mist,
    surfaceContainerHigh: AppColors.mist,
    surfaceContainerHighest: AppColors.mist,
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
  );

  static const _pillHeight = Size.fromHeight(54);
  static const _pillText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: Colors.white,
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.forest.withValues(alpha: 0.4)
              : AppColors.forest,
        ),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        minimumSize: const WidgetStatePropertyAll(_pillHeight),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 28),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        textStyle: const WidgetStatePropertyAll(_pillText),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white,
        minimumSize: _pillHeight,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        textStyle: _pillText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.forest,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
