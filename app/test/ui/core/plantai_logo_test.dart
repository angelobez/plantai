import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/core/widgets/leaf_icon.dart';
import 'package:plantai/ui/core/widgets/plantai_logo.dart';

void main() {
  testWidgets('shows the leaf, "Plant" and the "Aí" tag', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlantaiLogo())),
    );

    expect(find.byType(LeafIcon), findsOneWidget);
    expect(find.text('Plant'), findsOneWidget);
    expect(find.text('Aí'), findsOneWidget);
    expect(find.bySemanticsLabel('PlantAí'), findsOneWidget);
  });
}
