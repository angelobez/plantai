import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/garden/widgets/plant_name_dialog.dart';

import '../../testing/pump_screen.dart';

void main() {
  late List<String?> answers;

  setUp(() => answers = []);

  Future<void> open(WidgetTester tester, {String initialName = ''}) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => answers.add(
            await showPlantNameDialog(context, initialName: initialName),
          ),
          child: const Text('Abrir'),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('answers the name typed, trimmed', (tester) async {
    await open(tester);

    expect(find.text('Nome da planta'), findsWidgets);
    await tester.enterText(find.byType(TextField), '  Pimenta da vó ');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(answers, ['Pimenta da vó']);
  });

  testWidgets('starts with the name given', (tester) async {
    await open(tester, initialName: 'Jiboia');

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(answers, ['Jiboia']);
  });

  testWidgets('a blank name is refused', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Dê um nome para a planta.'), findsOneWidget);
    expect(answers, isEmpty);
  });

  testWidgets('a name over 80 characters is refused', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), 'a' * 81);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Use até 80 caracteres.'), findsOneWidget);
    expect(answers, isEmpty);
  });

  testWidgets('"Cancelar" answers null', (tester) async {
    await open(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(answers, [null]);
  });
}
