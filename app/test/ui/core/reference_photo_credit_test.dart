import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/core/widgets/reference_photo_credit.dart';

import '../../testing/fake_catalog_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  testWidgets('credits the author and license, and links to the source', (
    tester,
  ) async {
    final opened = <Uri>[];
    await pumpScreen(
      tester,
      Scaffold(
        body: ReferencePhotoCredit(
          photo: monsteraPhoto,
          openUrl: (url) async {
            opened.add(url);
            return true;
          },
        ),
      ),
    );

    expect(
      find.text(
        'Foto de referência: Ana Autora · CC BY-SA 4.0 · commons.wikimedia.org',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(ReferencePhotoCredit));

    expect(opened, [Uri.parse(monsteraPhoto.sourceUrl)]);
  });
}
