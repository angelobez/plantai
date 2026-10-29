import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/photo.dart';
import 'package:plantai/data/services/photo_picker/photo_picker.dart';
import 'package:plantai/domain/models/photo_failure.dart';
import 'package:plantai/ui/core/themes/theme.dart';
import 'package:plantai/ui/photo/view_models/photo_view_model.dart';
import 'package:plantai/ui/photo/widgets/photo_screen.dart';

import '../../testing/fake_photo_picker.dart';
import '../../testing/fake_photo_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakePhotoPicker photoPicker;
  late FakePhotoRepository photoRepository;
  late PhotoViewModel viewModel;
  late int closed;
  late List<Photo> identified;
  late List<Photo> searched;

  /// What the identification hands back: a source for another photo, or
  /// null when the User just came back.
  PhotoSource? identificationAnswer;

  setUp(() {
    photoPicker = FakePhotoPicker();
    photoRepository = FakePhotoRepository();
    viewModel = PhotoViewModel(
      photoPicker: photoPicker,
      photoRepository: photoRepository,
    );
    closed = 0;
    identified = [];
    searched = [];
    identificationAnswer = null;
  });

  Future<PhotoSource?> identify(Photo photo) async {
    identified.add(photo);
    return identificationAnswer;
  }

  Future<void> pumpPhoto(
    WidgetTester tester, {
    PhotoSource source = PhotoSource.camera,
  }) => pumpScreen(
    tester,
    PhotoScreen(
      viewModel: viewModel,
      initialSource: source,
      onClose: () => closed++,
      onIdentify: identify,
      onSearchByName: searched.add,
    ),
  );

  Finder action(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(InkWell));

  bool isEnabled(WidgetTester tester, String title) =>
      tester.widget<InkWell>(action(title)).onTap != null;

  testWidgets('opens the picker for the source it was given', (tester) async {
    await pumpPhoto(tester, source: PhotoSource.gallery);

    expect(photoPicker.asked, [PhotoSource.gallery]);
    expect(find.byKey(const Key('photo-preview')), findsOneWidget);
  });

  testWidgets('both actions wait for the upload, then pass the photo on', (
    tester,
  ) async {
    photoRepository.gate = Completer<void>();
    // Not pumpScreen: the spinner never lets the frames settle.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PhotoScreen(
          viewModel: viewModel,
          initialSource: PhotoSource.camera,
          onClose: () => closed++,
          onIdentify: identify,
          onSearchByName: searched.add,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Enviando a foto…'), findsOneWidget);
    expect(isEnabled(tester, 'Identificar pela foto'), isFalse);
    expect(isEnabled(tester, 'Buscar pelo nome'), isFalse);

    photoRepository.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Enviando a foto…'), findsNothing);
    await tester.tap(find.text('Identificar pela foto'));
    await tester.tap(find.text('Buscar pelo nome'));
    expect(identified.single.id, 'photo-1');
    expect(searched.single.id, 'photo-1');
  });

  testWidgets('without a connection keeps the photo and tries again', (
    tester,
  ) async {
    photoRepository.failure = PhotoFailure.noConnection;
    await pumpPhoto(tester);

    expect(find.textContaining('Sem conexão'), findsOneWidget);
    expect(find.byKey(const Key('photo-preview')), findsOneWidget);
    expect(isEnabled(tester, 'Identificar pela foto'), isFalse);

    photoRepository.failure = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(photoRepository.uploads, ['IMG_0001.jpg', 'IMG_0001.jpg']);
    expect(photoPicker.asked, hasLength(1));
    expect(isEnabled(tester, 'Identificar pela foto'), isTrue);
  });

  testWidgets('the daily limit says so, without "Tentar de novo"', (
    tester,
  ) async {
    photoRepository.failure = PhotoFailure.dailyLimit;
    await pumpPhoto(tester);

    expect(find.textContaining('50 fotos'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('"Tirar outra" asks the source again and sends the new photo', (
    tester,
  ) async {
    await pumpPhoto(tester);
    photoPicker.next = Picked(pickedPhoto('IMG_0002.jpg'));

    await tester.tap(find.text('Tirar outra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();

    expect(photoPicker.asked, [PhotoSource.camera, PhotoSource.gallery]);
    expect(photoRepository.uploads, ['IMG_0001.jpg', 'IMG_0002.jpg']);
    expect(closed, 0);
  });

  testWidgets('"Tirar outra foto" after the identification picks again', (
    tester,
  ) async {
    await pumpPhoto(tester);
    identificationAnswer = PhotoSource.gallery;

    await tester.tap(find.text('Identificar pela foto'));
    await tester.pumpAndSettle();

    expect(photoPicker.asked, [PhotoSource.camera, PhotoSource.gallery]);
    expect(photoRepository.uploads, hasLength(2));
  });

  testWidgets('coming back from the identification keeps the photo', (
    tester,
  ) async {
    await pumpPhoto(tester);

    await tester.tap(find.text('Identificar pela foto'));
    await tester.pumpAndSettle();

    expect(photoPicker.asked, [PhotoSource.camera]);
    expect(identified.single.id, 'photo-1');
  });

  testWidgets('canceling "Tirar outra" keeps the photo and the screen', (
    tester,
  ) async {
    await pumpPhoto(tester);
    photoPicker.next = const PickCancelled();

    await tester.tap(find.text('Tirar outra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(closed, 0);
    expect(find.byKey(const Key('photo-preview')), findsOneWidget);
    expect(isEnabled(tester, 'Buscar pelo nome'), isTrue);
  });

  testWidgets('canceling the first pick closes the screen', (tester) async {
    photoPicker.next = const PickCancelled();
    await pumpPhoto(tester);

    expect(closed, 1);
  });

  testWidgets('a refused camera offers the gallery', (tester) async {
    photoPicker.next = const CameraDenied();
    await pumpPhoto(tester);

    expect(closed, 0);
    expect(find.text('Tirar outra'), findsNothing);
    photoPicker.next = Picked(pickedPhoto());

    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();

    expect(photoPicker.asked.last, PhotoSource.gallery);
    expect(find.byKey(const Key('photo-preview')), findsOneWidget);
  });

  testWidgets('"Fechar" gives up', (tester) async {
    await pumpPhoto(tester);

    await tester.tap(find.byTooltip('Fechar'));

    expect(closed, 1);
  });

  testWidgets('without a flow plugged in, the actions still wait and enable', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      PhotoScreen(
        viewModel: viewModel,
        initialSource: PhotoSource.camera,
        onClose: () => closed++,
      ),
    );

    expect(isEnabled(tester, 'Identificar pela foto'), isTrue);
    await tester.tap(find.text('Identificar pela foto'));
    await tester.pumpAndSettle();
    expect(find.text('Que planta é essa?'), findsOneWidget);
  });
}
