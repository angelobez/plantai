import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/health_failure.dart';
import 'package:plantai/ui/home/view_models/home_view_model.dart';
import 'package:plantai/ui/home/widgets/home_screen.dart';

import '../../testing/fake_health_repository.dart';

void main() {
  late FakeHealthRepository repository;
  late HomeViewModel viewModel;
  late List<Uri> openedUrls;

  setUp(() {
    repository = FakeHealthRepository();
    openedUrls = [];
  });

  tearDown(() => viewModel.dispose());

  // The view model is created inside the test body, so its pending check runs
  // in the test's fake-async zone and settles with `pump`.
  Future<void> pumpHome(WidgetTester tester) {
    viewModel = HomeViewModel(healthRepository: repository);
    return tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          viewModel: viewModel,
          openUrl: (url) async {
            openedUrls.add(url);
            return true;
          },
        ),
      ),
    );
  }

  final retryButton = find.widgetWithText(FilledButton, 'Tentar de novo');

  testWidgets('shows a progress indicator while loading', (tester) async {
    await pumpHome(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(retryButton, findsNothing);
  });

  testWidgets('shows the API and PostGIS versions when connected', (
    tester,
  ) async {
    await pumpHome(tester);
    repository.succeed(apiVersion: '0.0.1', postgisVersion: '3.5.2');
    await tester.pumpAndSettle();

    expect(find.text('Conectado à API'), findsOneWidget);
    expect(find.text('Versão da API: 0.0.1'), findsOneWidget);
    expect(find.text('Versão do PostGIS: 3.5.2'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(retryButton, findsNothing);
  });

  final retryableFailures = <String, (HealthFailure, String)>{
    'API unreachable': (
      HealthFailure.noConnection,
      'Não foi possível falar com a API',
    ),
    'database down': (
      HealthFailure.databaseDown,
      'A API respondeu, mas o banco de dados está fora do ar',
    ),
    'unknown error': (
      HealthFailure.unknown,
      'Algo deu errado ao falar com a API',
    ),
  };

  for (final MapEntry(key: name, value: (error, message))
      in retryableFailures.entries) {
    testWidgets('$name: shows its message and "Tentar de novo"', (
      tester,
    ) async {
      await pumpHome(tester);
      repository.fail(error);
      await tester.pumpAndSettle();

      expect(find.textContaining(message), findsOneWidget);
      expect(retryButton, findsOneWidget);
      expect(find.text('Atualize o PlantAí'), findsNothing);
    });
  }

  testWidgets('"Tentar de novo" loads again', (tester) async {
    await pumpHome(tester);
    repository.fail(HealthFailure.noConnection);
    await tester.pumpAndSettle();

    await tester.tap(retryButton);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.succeed(apiVersion: '0.0.1');
    await tester.pumpAndSettle();
    expect(find.text('Versão da API: 0.0.1'), findsOneWidget);
  });

  testWidgets('update required: shows the release link and no retry', (
    tester,
  ) async {
    await pumpHome(tester);
    repository.fail(HealthFailure.updateRequired);
    await tester.pumpAndSettle();

    expect(find.text('Atualize o PlantAí'), findsOneWidget);
    expect(retryButton, findsNothing);

    const releases = 'https://github.com/angelobez/plantai/releases';
    await tester.tap(find.text(releases));
    expect(openedUrls, [Uri.parse(releases)]);
  });
}
