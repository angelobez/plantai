import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/photo.dart';
import 'package:plantai/data/services/api/models/species_summary.dart';
import 'package:plantai/domain/models/identification_failure.dart';
import 'package:plantai/ui/core/widgets/photo_image.dart';
import 'package:plantai/ui/identification/view_models/candidates_view_model.dart';
import 'package:plantai/ui/identification/widgets/candidates_screen.dart';

import '../../testing/fake_identification_repository.dart';
import '../../testing/pump_screen.dart';

final _photo = Photo(
  id: '0190e0d4-0000-7000-8000-0000000000aa',
  url: 'https://photo-storage.fake/photos/aa.jpg',
  expiresAt: DateTime.utc(2026, 11, 3, 15),
);

void main() {
  late FakeIdentificationRepository repository;
  late List<SpeciesSummary> chosen;
  late List<String> events;
  late List<Uri> openedUrls;

  setUp(() {
    repository = FakeIdentificationRepository();
    chosen = [];
    events = [];
    openedUrls = [];
  });

  Future<CandidatesViewModel> pump(
    WidgetTester tester, {
    bool settle = true,
    VoidCallback? onSaveNameOnly,
  }) async {
    final viewModel = CandidatesViewModel(
      identificationRepository: repository,
      photoId: _photo.id,
    )..identify();
    final screen = CandidatesScreen(
      viewModel: viewModel,
      photo: _photo,
      openUrl: (url) async {
        openedUrls.add(url);
        return true;
      },
      onSpecies: chosen.add,
      onNoneOfThese: () => events.add('none'),
      onTakeAnother: () => events.add('take another'),
      onSearchByName: () => events.add('search'),
      onSaveNameOnly: onSaveNameOnly,
    );
    if (settle) {
      await pumpScreen(tester, screen, below: const Text('Foto'));
    } else {
      await tester.pumpWidget(MaterialApp(home: screen));
    }
    return viewModel;
  }

  Finder button(String label) => find.ancestor(
    of: find.text(label),
    matching: find.bySubtype<ButtonStyleButton>(),
  );

  bool isEnabled(WidgetTester tester, String label) =>
      tester.widget<ButtonStyleButton>(button(label)).onPressed != null;

  testWidgets('says it is identifying while Pl@ntNet answers', (tester) async {
    repository.gate = Completer();
    await pump(tester, settle: false);

    expect(find.text('Identificando a planta…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.gate!.complete();
    await tester.pump();
    expect(find.text('Qual destas é a sua?'), findsOneWidget);
  });

  group('Candidatos', () {
    testWidgets('shows each candidate with its photos, names and credit', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Qual destas é a sua?'), findsOneWidget);
      expect(find.text('Jiboia'), findsOneWidget);
      expect(find.text('Epipremnum aureum'), findsOneWidget);
      // Without a common name, the scientific name is the title.
      expect(find.text('Epipremnum pinnatum'), findsOneWidget);
      expect(button('É esta'), findsNWidgets(2));
      final images = tester
          .widgetList<ReferencePhotoImage>(find.byType(ReferencePhotoImage))
          .map((image) => image.photo.sourceUrl);
      expect(images, [
        'https://bs.plantnet.org/image/o/jiboia-1',
        'https://bs.plantnet.org/image/o/jiboia-2',
        'https://bs.plantnet.org/image/o/pinnatum-1',
      ]);
      expect(
        find.text('Fotos: Ana Ribeiro · CC BY-SA, Carlos Lima · CC BY'),
        findsOneWidget,
      );
      expect(find.text('Fotos: Pedro Alves · CC BY-SA'), findsOneWidget);
      expect(
        find.text(
          'Identificação: Pl@ntNet · fotos de referência dos autores no '
          'Pl@ntNet',
        ),
        findsOneWidget,
      );
      expect(find.text('Restam 7 de 10 identificações hoje'), findsOneWidget);
      // The User's own photo, to compare.
      expect(
        tester.widget<PhotoImage>(find.byType(PhotoImage)).photo,
        same(_photo),
      );
    });

    testWidgets('a candidate photo opens its page on Pl@ntNet', (tester) async {
      await pump(tester);

      await tester.tap(find.byType(ReferencePhotoImage).first);

      expect(openedUrls, [
        Uri.parse('https://bs.plantnet.org/image/o/jiboia-1'),
      ]);
    });

    testWidgets('"É esta" opens the chosen species', (tester) async {
      await pump(tester);

      await tester.tap(button('É esta').last);
      await tester.pumpAndSettle();

      expect(repository.choices, [(recognized.id, 1)]);
      expect(chosen, [jiboiaSpecies]);
    });

    testWidgets('a choice that fails stays, with the message', (tester) async {
      await pump(tester);
      repository.failure = IdentificationFailure.noConnection;

      await tester.tap(button('É esta').first);
      await tester.pumpAndSettle();

      expect(chosen, isEmpty);
      expect(
        find.text(
          'Sem conexão com a internet. Confira a rede e tente de novo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Jiboia'), findsOneWidget);
    });

    testWidgets('"Nenhuma destas" records it and goes on', (tester) async {
      await pump(tester);

      await tester.tap(button('Nenhuma destas'));
      await tester.pumpAndSettle();

      expect(repository.choices, [(recognized.id, null)]);
      expect(events, ['none']);
    });

    testWidgets('the buttons wait while a choice is on its way', (
      tester,
    ) async {
      await pump(tester);
      repository.gate = Completer();

      await tester.tap(button('É esta').first);
      await tester.pump();

      expect(isEnabled(tester, 'Nenhuma destas'), isFalse);
      repository.gate!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('when it fails', () {
    testWidgets('offline shows the message and "Tentar de novo"', (
      tester,
    ) async {
      repository.failure = IdentificationFailure.noConnection;
      await pump(tester);

      expect(
        find.text(
          'Sem conexão com a internet. Confira a rede e tente de novo.',
        ),
        findsOneWidget,
      );

      repository.failure = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(repository.identified, hasLength(2));
      expect(find.text('Qual destas é a sua?'), findsOneWidget);
    });

    testWidgets('still offers the search', (tester) async {
      repository.failure = IdentificationFailure.serviceUnavailable;
      await pump(tester);

      await tester.tap(button('Buscar pelo nome'));

      expect(events, ['search']);
    });

    testWidgets('a photo that is gone has no "Tentar de novo"', (tester) async {
      repository.failure = IdentificationFailure.notFound;
      await pump(tester);

      expect(
        find.text('Essa foto não está mais disponível. Tire outra foto.'),
        findsOneWidget,
      );
      expect(find.text('Tentar de novo'), findsNothing);
    });
  });

  group('Foto não reconhecida', () {
    setUp(() => repository.identification = notRecognized);

    testWidgets('explains and offers the three ways out', (tester) async {
      await pump(tester);

      expect(find.text('Não consegui reconhecer'), findsOneWidget);
      expect(
        find.text('Tente outra foto: uma folha ou flor de perto, com boa luz.'),
        findsOneWidget,
      );

      await tester.tap(button('Tirar outra foto'));
      await tester.tap(button('Buscar pelo nome'));
      expect(events, ['take another', 'search']);
    });

    testWidgets('"Salvar só com o nome" does not show without saving', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Salvar só com o nome'), findsNothing);
    });

    testWidgets('"Salvar só com o nome" works once the flow is there', (
      tester,
    ) async {
      await pump(tester, onSaveNameOnly: () => events.add('save'));

      await tester.tap(button('Salvar só com o nome'));

      expect(events, ['save']);
    });
  });

  group('Limite diário', () {
    setUp(() => repository.failure = IdentificationFailure.dailyLimit);

    testWidgets('says the 10 are used and keeps the search', (tester) async {
      await pump(tester);

      expect(find.text('Que planta é essa?'), findsOneWidget);
      expect(
        find.text('Você usou suas 10 identificações de hoje; amanhã tem mais'),
        findsOneWidget,
      );
      expect(find.text('A busca continua liberada'), findsOneWidget);
      expect(find.text('Salvar só com o nome'), findsNothing);

      await tester.tap(find.text('Buscar pelo nome'));
      expect(events, ['search']);
    });

    testWidgets('"Identificar pela foto" is off', (tester) async {
      await pump(tester);

      final identify = find.ancestor(
        of: find.text('Identificar pela foto'),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(identify).onTap, isNull);
    });
  });
}
