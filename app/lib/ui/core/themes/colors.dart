import 'package:flutter/material.dart';

/// The PlantAí palette, from the screens drawn in Claude Design
/// (`prototype/telas-do-mvp`).
abstract final class AppColors {
  /// Sage green, the brand's light accent.
  static const sage = Color(0xFFA9C9AE);

  /// Dark green: main buttons, the logo and the selected tab.
  static const forest = Color(0xFF3F6B4A);

  /// Very light green for soft backgrounds (segmented tabs, empty states).
  static const mist = Color(0xFFEEF4EF);

  /// Main text.
  static const ink = Color(0xFF1F2A22);

  /// Secondary text and unselected icons.
  static const inkMuted = Color(0xFF5B665E);

  /// Hairlines between sections, the header and the bottom bar.
  static const divider = Color(0xFFEDF2EE);

  /// Borders of outlined buttons and fields.
  static const border = Color(0xFFD3DED6);

  /// Destructive actions, such as "Sair".
  static const danger = Color(0xFFA3361F);
}
