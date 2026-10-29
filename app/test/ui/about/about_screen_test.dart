import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/about/widgets/about_screen.dart';

import '../../testing/pump_screen.dart';

void main() {
  late List<Uri> openedUrls;

  setUp(() => openedUrls = []);

  Future<void> pump(WidgetTester tester) => pumpScreen(
    tester,
    AboutScreen(
      openUrl: (url) async {
        openedUrls.add(url);
        return true;
      },
    ),
    below: const Text('Perfil'),
  );

  Future<void> tapCredit(WidgetTester tester, String title) async {
    final credit = find.text(title);
    await tester.scrollUntilVisible(credit, 100);
    await tester.tap(credit);
    await tester.pump();
  }

  testWidgets('shows the title and the project line', (tester) async {
    await pump(tester);

    expect(find.text('Sobre e créditos'), findsOneWidget);
    expect(find.textContaining('projeto de portfólio'), findsOneWidget);
  });

  testWidgets('warns that the care tips are written by AI (Claude)', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Claude, da Anthropic'), findsOneWidget);
    expect(find.textContaining('geradas por IA'), findsOneWidget);
  });

  testWidgets('shows the Manrope license', (tester) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Fonte Manrope'), 100);

    expect(find.textContaining('SIL Open Font License 1.1'), findsOneWidget);
  });

  for (final (title, url) in [
    ('Pl@ntNet', 'https://plantnet.org/'),
    ('Claude, da Anthropic', 'https://www.anthropic.com/claude'),
    ('Flora e Funga do Brasil', 'https://floradobrasil.jbrj.gov.br/'),
    ('GBIF', 'https://www.gbif.org/'),
    ('Wikimedia Commons', 'https://commons.wikimedia.org/'),
    ('Fonte Manrope', 'https://github.com/googlefonts/manrope'),
  ]) {
    testWidgets('$title opens its origin', (tester) async {
      await pump(tester);

      await tapCredit(tester, title);

      expect(openedUrls, [Uri.parse(url)]);
    });
  }

  testWidgets('Voltar goes back', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Sobre e créditos'), findsNothing);
  });
}
