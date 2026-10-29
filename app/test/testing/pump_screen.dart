import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/core/themes/theme.dart';

/// Pumps [screen] alone, with the app theme, as the first route of a
/// [Navigator] (so "back" has somewhere to go when [below] is given).
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Widget? below,
}) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: below ?? screen),
  );
  if (below != null) {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
  }
  await tester.pumpAndSettle();
}
