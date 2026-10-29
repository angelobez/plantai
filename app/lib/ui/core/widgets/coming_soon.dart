import 'package:flutter/material.dart';

import 'empty_state.dart';

/// Placeholder for a screen that is not built yet: an icon tile, [title] and
/// "Em breve", in the empty-state layout of the Claude Design screens.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.icon, required this.title});

  final Widget icon;
  final String title;

  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: icon, title: title, message: 'Em breve');
}
