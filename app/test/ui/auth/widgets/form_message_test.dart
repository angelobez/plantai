import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/auth/widgets/form_message.dart';

import '../../../testing/pump_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, FormMessage message) =>
      pumpScreen(tester, Scaffold(body: message));

  Finder retryButton() => find.widgetWithText(TextButton, 'Tentar de novo');

  testWidgets('an error with onRetry offers "Tentar de novo"', (tester) async {
    var retried = 0;
    await pump(
      tester,
      FormMessage(error: 'Sem conexão', onRetry: () => retried++),
    );

    await tester.tap(retryButton());

    expect(find.text('Sem conexão'), findsOneWidget);
    expect(retried, 1);
  });

  testWidgets('an error without onRetry is only the message', (tester) async {
    await pump(tester, const FormMessage(error: 'Código errado'));

    expect(find.text('Código errado'), findsOneWidget);
    expect(retryButton(), findsNothing);
  });

  testWidgets('a notice never offers "Tentar de novo"', (tester) async {
    await pump(
      tester,
      FormMessage(notice: 'Enviamos um código novo.', onRetry: () {}),
    );

    expect(retryButton(), findsNothing);
  });
}
