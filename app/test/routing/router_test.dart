import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/main.dart';
import 'package:plantai/ui/core/widgets/plantai_logo.dart';

void main() {
  late UpdateRequired updateRequired;
  late List<Uri> openedUrls;

  setUp(() {
    updateRequired = UpdateRequired();
    openedUrls = [];
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      PlantaiApp(
        updateRequired: updateRequired,
        openUrl: (url) async {
          openedUrls.add(url);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tab(String label) => find.descendant(
    of: find.byKey(const Key('bottom-bar')),
    matching: find.text(label),
  );

  Finder cameraButton() =>
      find.bySemanticsLabel('Identificar uma planta pela foto');

  testWidgets('opens on Por perto, with the logo and "em breve"', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Mudas por perto'), findsOneWidget);
    expect(find.text('Em breve'), findsOneWidget);
    expect(find.byType(PlantaiLogo), findsOneWidget);
    expect(tab('Jardim'), findsOneWidget);
    expect(tab('Por perto'), findsOneWidget);
    expect(tab('Perfil'), findsOneWidget);
    expect(cameraButton(), findsOneWidget);
  });

  testWidgets('the tabs switch screens', (tester) async {
    await pumpApp(tester);

    await tester.tap(tab('Jardim'));
    await tester.pumpAndSettle();
    expect(find.text('Meu jardim'), findsOneWidget);
    expect(find.text('Mudas por perto'), findsNothing);

    await tester.tap(tab('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Seu perfil'), findsOneWidget);
    expect(find.text('Meu jardim'), findsNothing);

    await tester.tap(tab('Por perto'));
    await tester.pumpAndSettle();
    expect(find.text('Mudas por perto'), findsOneWidget);
    expect(find.text('Seu perfil'), findsNothing);
  });

  testWidgets('the camera button shows "em breve" and goes back', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(cameraButton());
    await tester.pumpAndSettle();
    expect(find.text('Identificar pela foto'), findsOneWidget);
    expect(find.text('Em breve'), findsOneWidget);
    expect(find.byKey(const Key('bottom-bar')), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Mudas por perto'), findsOneWidget);
  });

  testWidgets('update required: shows "Atualize o PlantAí" with the link', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(tab('Jardim'));
    await tester.pumpAndSettle();

    updateRequired.raise();
    await tester.pumpAndSettle();

    expect(find.text('Atualize o PlantAí'), findsOneWidget);
    expect(find.byKey(const Key('bottom-bar')), findsNothing);

    const releases = 'https://github.com/angelobez/plantai/releases';
    await tester.tap(find.text(releases));
    expect(openedUrls, [Uri.parse(releases)]);
  });

  testWidgets('update required: there is no way back to the tabs', (
    tester,
  ) async {
    updateRequired.raise();
    await pumpApp(tester);

    expect(find.text('Atualize o PlantAí'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });
}
