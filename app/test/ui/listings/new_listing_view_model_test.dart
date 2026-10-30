import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/photo_picker/photo_picker.dart';
import 'package:plantai/domain/models/listing_draft.dart';
import 'package:plantai/domain/models/listing_failure.dart';
import 'package:plantai/domain/models/photo_failure.dart';
import 'package:plantai/ui/listings/view_models/new_listing_view_model.dart';

import '../../testing/fake_garden_repository.dart';
import '../../testing/fake_listing_repository.dart';
import '../../testing/fake_photo_picker.dart';
import '../../testing/fake_photo_repository.dart';

/// "Doar mudas" on the Tela da planta of [monsteraDaSala].
final fromPlant = ListingDraft(
  photo: jiboiaPhoto,
  commonName: 'Monstera da sala',
  species: const ListingDraftSpecies(
    id: '0190e0d4-0000-7000-8000-0000000000c1',
    scientificName: 'Monstera deliciosa',
  ),
  plantId: monsteraDaSala.id,
);

void main() {
  late FakeListingRepository listingRepository;
  late FakePhotoRepository photoRepository;
  late FakePhotoPicker photoPicker;

  setUp(() {
    listingRepository = FakeListingRepository();
    photoRepository = FakePhotoRepository();
    photoPicker = FakePhotoPicker();
  });

  NewListingViewModel viewModelFor([ListingDraft? draft]) =>
      NewListingViewModel(
        listingRepository: listingRepository,
        photoRepository: photoRepository,
        photoPicker: photoPicker,
        draft: draft ?? fromPlant,
      );

  test('starts with the plant’s photo, name and species, and 1 seedling', () {
    final viewModel = viewModelFor();

    expect(viewModel.photo, jiboiaPhoto);
    expect(viewModel.isPlantPhoto, isTrue);
    expect(viewModel.commonName, 'Monstera da sala');
    expect(viewModel.species?.scientificName, 'Monstera deliciosa');
    expect(viewModel.quantity, 1);
    expect(viewModel.note, '');
  });

  test('a draft without a plant is not the plant’s photo', () {
    final viewModel = viewModelFor(
      ListingDraft(photo: jiboiaPhoto, commonName: 'Jiboia'),
    );

    expect(viewModel.isPlantPhoto, isFalse);
    expect(viewModel.species, isNull);
  });

  test('the quantity goes from 1 to 99', () {
    final viewModel = viewModelFor();
    expect(viewModel.canDecrease, isFalse);

    viewModel.decrease();
    expect(viewModel.quantity, 1);

    for (var i = 0; i < 120; i++) {
      viewModel.increase();
    }
    expect(viewModel.quantity, 99);
    expect(viewModel.canIncrease, isFalse);

    viewModel.decrease();
    expect(viewModel.quantity, 98);
    expect(viewModel.canIncrease, isTrue);
  });

  group('takeAnotherPhoto', () {
    test('sends a new photo, which replaces the plant’s', () async {
      final viewModel = viewModelFor();

      await viewModel.takeAnotherPhoto(PhotoSource.camera);

      expect(photoPicker.asked, [PhotoSource.camera]);
      expect(photoRepository.uploads, ['IMG_0001.jpg']);
      expect(viewModel.photo.id, 'photo-1');
      expect(viewModel.isPlantPhoto, isFalse);
      expect(viewModel.photoError, isNull);
    });

    test('shows the progress while the photo goes', () async {
      final viewModel = viewModelFor();
      photoRepository.gate = Completer<void>();

      final taking = viewModel.takeAnotherPhoto(PhotoSource.gallery);
      await pumpEventQueue();
      expect(viewModel.isTakingPhoto, isTrue);

      photoRepository.gate!.complete();
      await taking;
      expect(viewModel.isTakingPhoto, isFalse);
    });

    test('cancelling keeps the photo', () async {
      photoPicker.next = const PickCancelled();
      final viewModel = viewModelFor();

      await viewModel.takeAnotherPhoto(PhotoSource.camera);

      expect(viewModel.photo, jiboiaPhoto);
      expect(viewModel.photoError, isNull);
      expect(photoRepository.uploads, isEmpty);
    });

    test('says so when the camera is denied', () async {
      photoPicker.next = const CameraDenied();
      final viewModel = viewModelFor();

      await viewModel.takeAnotherPhoto(PhotoSource.camera);

      expect(viewModel.photo, jiboiaPhoto);
      expect(
        viewModel.photoError,
        'O PlantAí não tem acesso à câmera. Libere nas configurações do '
        'celular ou escolha uma foto da galeria.',
      );
    });

    test('says so when the upload fails, and keeps the photo', () async {
      photoRepository.failure = PhotoFailure.noConnection;
      final viewModel = viewModelFor();

      await viewModel.takeAnotherPhoto(PhotoSource.camera);

      expect(viewModel.photo, jiboiaPhoto);
      expect(
        viewModel.photoError,
        'Sem conexão com a internet. Confira a rede e tente de novo.',
      );
    });
  });

  group('publish', () {
    test(
      'publishes the listing with the plant, species, quantity and note',
      () async {
        final viewModel = viewModelFor()
          ..updateName('  Costela-de-adão ')
          ..increase()
          ..increase()
          ..updateNote(' Pegar à tarde ');

        final outcome = await viewModel.publish();

        expect(outcome, isA<Published>());
        final sent = listingRepository.created.single;
        expect(sent.photoId, jiboiaPhoto.id);
        expect(sent.commonName, 'Costela-de-adão');
        expect(sent.quantity, 3);
        expect(sent.speciesId, '0190e0d4-0000-7000-8000-0000000000c1');
        expect(sent.plantId, monsteraDaSala.id);
        expect(sent.note, 'Pegar à tarde');
        expect((outcome as Published).listing.commonName, 'Costela-de-adão');
      },
    );

    test('publishes with the new photo of the seedling', () async {
      final viewModel = viewModelFor();
      await viewModel.takeAnotherPhoto(PhotoSource.camera);

      await viewModel.publish();

      expect(listingRepository.created.single.photoId, 'photo-1');
    });

    test('an empty name is not sent', () async {
      final viewModel = viewModelFor()..updateName('   ');

      final outcome = await viewModel.publish();

      expect(outcome, isA<NotPublished>());
      expect(viewModel.nameError, 'Dê um nome para a planta.');
      expect(listingRepository.created, isEmpty);

      viewModel.updateName('Jiboia');
      expect(viewModel.nameError, isNull);
    });

    test('a name over 80 characters is not sent', () async {
      final viewModel = viewModelFor()..updateName('a' * 81);

      await viewModel.publish();

      expect(viewModel.nameError, 'Use até 80 caracteres.');
      expect(listingRepository.created, isEmpty);
    });

    test('shows the progress while publishing', () async {
      final viewModel = viewModelFor();
      listingRepository.gate = Completer<void>();

      final publishing = viewModel.publish();
      await pumpEventQueue();
      expect(viewModel.isPublishing, isTrue);

      listingRepository.gate!.complete();
      await publishing;
      expect(viewModel.isPublishing, isFalse);
    });

    test('DONATION_PROFILE_REQUIRED asks for the Primeiro anúncio', () async {
      listingRepository.createFailures.add(
        ListingFailure.donationProfileRequired,
      );
      final viewModel = viewModelFor();

      final outcome = await viewModel.publish();

      expect(outcome, isA<DonationProfileNeeded>());
      expect(viewModel.publishError, isNull);
      expect(await viewModel.publish(), isA<Published>());
    });

    test('no connection can be tried again', () async {
      listingRepository.failure = ListingFailure.noConnection;
      final viewModel = viewModelFor();

      expect(await viewModel.publish(), isA<NotPublished>());

      expect(
        viewModel.publishError,
        'Sem conexão com a internet. Confira a rede e tente de novo.',
      );
      expect(viewModel.canRetryPublish, isTrue);
    });

    test('a photo that is gone asks for another one', () async {
      listingRepository.failure = ListingFailure.notFound;
      final viewModel = viewModelFor();

      await viewModel.publish();

      expect(
        viewModel.publishError,
        'Essa foto não está mais disponível. Tire outra foto.',
      );
      expect(viewModel.canRetryPublish, isFalse);
    });
  });
}
