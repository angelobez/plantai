import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/auth/login/widgets/login_screen.dart';
import 'package:plantai/ui/core/widgets/plantai_logo.dart';

import '../../../testing/pump_screen.dart';

void main() {
  testWidgets('shows the logo, the tagline and both ways in', (tester) async {
    await pumpScreen(tester, LoginScreen(onEmail: () {}));

    expect(find.byType(PlantaiLogo), findsOneWidget);
    expect(find.textContaining('Descubra que planta é essa'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.text('Entrar com e-mail'), findsOneWidget);
  });

  testWidgets('"Entrar com e-mail" calls onEmail', (tester) async {
    var tapped = 0;
    await pumpScreen(tester, LoginScreen(onEmail: () => tapped++));

    await tester.tap(find.text('Entrar com e-mail'));

    expect(tapped, 1);
  });

  testWidgets('"Entrar com Google" says "em breve" for now', (tester) async {
    await pumpScreen(tester, LoginScreen(onEmail: () {}));

    await tester.tap(find.text('Entrar com Google'));
    await tester.pump();

    expect(find.text('Entrar com Google: em breve'), findsOneWidget);
  });

  testWidgets('"Entrar com Google" calls onGoogle when given', (tester) async {
    var tapped = 0;
    await pumpScreen(
      tester,
      LoginScreen(onEmail: () {}, onGoogle: () => tapped++),
    );

    await tester.tap(find.text('Entrar com Google'));
    await tester.pump();

    expect(tapped, 1);
    expect(find.byType(SnackBar), findsNothing);
  });
}
