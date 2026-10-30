import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/photo_picker/photo_picker.dart';
import 'package:plantai/domain/models/photo_failure.dart';
import 'package:plantai/ui/photo/view_models/photo_view_model.dart';

import '../../testing/fake_photo_picker.dart';
import '../../testing/fake_photo_repository.dart';

void main() {
  late FakePhotoPicker photoPicker;
  late FakePhotoRepository photoRepository;
  late PhotoViewModel viewModel;

  setUp(() {
    photoPicker = FakePhotoPicker();
    photoRepository = FakePhotoRepository();
    viewModel = PhotoViewModel(
      photoPicker: photoPicker,
      photoRepository: photoRepository,
    );
  });

  group('pick', () {
    test('shows the photo at once and sends it meanwhile', () async {
      photoRepository.gate = Completer<void>();

      final picking = viewModel.pick(PhotoSource.camera);
      await pumpEventQueue();

      expect(photoPicker.asked, [PhotoSource.camera]);
      expect(viewModel.picked?.filename, 'IMG_0001.jpg');
      expect(viewModel.isUploading, isTrue);
      expect(viewModel.photo, isNull);
      expect(viewModel.isReady, isFalse);

      photoRepository.gate!.complete();
      expect(await picking, isTrue);

      expect(viewModel.isUploading, isFalse);
      expect(viewModel.photo?.id, 'photo-1');
      expect(viewModel.isReady, isTrue);
      expect(viewModel.uploadError, isNull);
      expect(photoRepository.uploads, ['IMG_0001.jpg']);
    });

    test('canceling the first pick is no error, and gives up', () async {
      photoPicker.next = const PickCancelled();

      expect(await viewModel.pick(PhotoSource.gallery), isFalse);

      expect(viewModel.picked, isNull);
      expect(viewModel.pickError, isNull);
      expect(viewModel.cameraDenied, isFalse);
      expect(photoRepository.uploads, isEmpty);
    });

    test('canceling "Tirar outra" keeps the photo already sent', () async {
      await viewModel.pick(PhotoSource.camera);
      photoPicker.next = const PickCancelled();

      expect(await viewModel.pick(PhotoSource.camera), isTrue);

      expect(viewModel.picked?.filename, 'IMG_0001.jpg');
      expect(viewModel.photo?.id, 'photo-1');
      expect(photoRepository.uploads, hasLength(1));
    });

    test('another photo replaces the first and is sent too', () async {
      await viewModel.pick(PhotoSource.camera);
      photoPicker.next = Picked(pickedPhoto('IMG_0002.jpg'));

      await viewModel.pick(PhotoSource.gallery);

      expect(viewModel.picked?.filename, 'IMG_0002.jpg');
      expect(viewModel.photo?.id, 'photo-2');
    });

    test(
      'an upload that ends after another photo was picked is ignored',
      () async {
        final firstUpload = Completer<void>();
        photoRepository.gate = firstUpload;
        final first = viewModel.pick(PhotoSource.camera);
        await pumpEventQueue();

        photoRepository.gate = null;
        photoPicker.next = Picked(pickedPhoto('IMG_0002.jpg'));
        await viewModel.pick(PhotoSource.camera);
        firstUpload.complete();
        await first;

        expect(viewModel.picked?.filename, 'IMG_0002.jpg');
        expect(viewModel.photo?.id, 'photo-2');
        expect(viewModel.isUploading, isFalse);
      },
    );

    test('a refused camera says so and offers the gallery', () async {
      photoPicker.next = const CameraDenied();

      expect(await viewModel.pick(PhotoSource.camera), isTrue);

      expect(viewModel.cameraDenied, isTrue);
      expect(viewModel.pickError, contains('câmera'));
      expect(viewModel.pickError, contains('galeria'));
      expect(viewModel.picked, isNull);
    });

    test('the gallery after a refused camera clears the message', () async {
      photoPicker.next = const CameraDenied();
      await viewModel.pick(PhotoSource.camera);
      photoPicker.next = Picked(pickedPhoto());

      await viewModel.pick(PhotoSource.gallery);

      expect(viewModel.cameraDenied, isFalse);
      expect(viewModel.pickError, isNull);
      expect(viewModel.photo, isNotNull);
    });

    test('a picker that fails says so', () async {
      photoPicker.next = const PickFailed();

      expect(await viewModel.pick(PhotoSource.gallery), isTrue);

      expect(viewModel.pickError, isNotNull);
      expect(viewModel.cameraDenied, isFalse);
    });

    test('notifies while picking and when done', () async {
      var notified = 0;
      viewModel.addListener(() => notified++);
      photoPicker.gate = Completer<void>();

      final picking = viewModel.pick(PhotoSource.camera);
      expect(viewModel.isPicking, isTrue);
      photoPicker.gate!.complete();
      await picking;

      expect(viewModel.isPicking, isFalse);
      expect(notified, greaterThanOrEqualTo(3));
    });
  });

  group('upload failures', () {
    test(
      'without a connection, keeps the photo and offers to try again',
      () async {
        photoRepository.failure = PhotoFailure.noConnection;

        await viewModel.pick(PhotoSource.camera);

        expect(viewModel.picked, isNotNull);
        expect(viewModel.photo, isNull);
        expect(viewModel.isReady, isFalse);
        expect(viewModel.uploadError, contains('Sem conexão'));
        expect(viewModel.canRetryUpload, isTrue);
      },
    );

    test('"Tentar de novo" sends the same photo again', () async {
      photoRepository.failure = PhotoFailure.noConnection;
      await viewModel.pick(PhotoSource.camera);
      photoRepository.failure = null;

      await viewModel.retryUpload();

      expect(photoRepository.uploads, ['IMG_0001.jpg', 'IMG_0001.jpg']);
      expect(photoPicker.asked, hasLength(1));
      expect(viewModel.photo?.id, 'photo-2');
      expect(viewModel.uploadError, isNull);
      expect(viewModel.canRetryUpload, isFalse);
    });

    test('the daily limit says so, with nothing to try again', () async {
      photoRepository.failure = PhotoFailure.dailyLimit;

      await viewModel.pick(PhotoSource.camera);

      expect(viewModel.uploadError, contains('50 fotos'));
      expect(viewModel.canRetryUpload, isFalse);
    });

    test('a file the API cannot read asks for another photo', () async {
      photoRepository.failure = PhotoFailure.notAnImage;

      await viewModel.pick(PhotoSource.gallery);

      expect(viewModel.uploadError, contains('outra foto'));
      expect(viewModel.canRetryUpload, isFalse);
    });

    test('anything else offers to try again', () async {
      photoRepository.failure = PhotoFailure.unknown;

      await viewModel.pick(PhotoSource.gallery);

      expect(viewModel.uploadError, 'Algo deu errado. Tente de novo.');
      expect(viewModel.canRetryUpload, isTrue);
    });
  });

  test('does not notify after dispose', () async {
    photoRepository.gate = Completer<void>();
    final picking = viewModel.pick(PhotoSource.camera);
    await pumpEventQueue();

    viewModel.dispose();
    photoRepository.gate!.complete();

    await expectLater(picking, completes);
  });
}
