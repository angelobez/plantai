import 'package:flutter/foundation.dart';

import '../../../data/repositories/listing/listing_repository.dart';
import '../../../data/repositories/photo/photo_repository.dart';
import '../../../data/services/api/models/listing.dart';
import '../../../data/services/api/models/photo.dart';
import '../../../data/services/photo_picker/photo_picker.dart';
import '../../../domain/models/listing_draft.dart';
import '../../../domain/models/listing_failure.dart';
import '../../../domain/models/new_listing.dart';
import '../../../domain/models/photo_failure.dart';
import '../../core/view_models/safe_notify.dart';
import '../../photo/photo_failure_message.dart';
import '../../photo/view_models/photo_view_model.dart';
import '../listing_failure_message.dart';

/// What [NewListingViewModel.publish] came to.
sealed class PublishOutcome {
  const PublishOutcome();
}

/// The listing is up; Meus anúncios shows it.
final class Published extends PublishOutcome {
  const Published(this.listing);

  final MyListing listing;
}

/// The API asked for the donation profile first
/// (`DONATION_PROFILE_REQUIRED`): the Primeiro anúncio, then publish again.
final class DonationProfileNeeded extends PublishOutcome {
  const DonationProfileNeeded();
}

/// Nothing was published: a field is wrong or the call failed; the errors
/// say why.
final class NotPublished extends PublishOutcome {
  const NotPublished();
}

/// Novo anúncio: the form a listing is published from, starting from a
/// [ListingDraft] (a plant of Meu jardim, or a new photo of the seedling).
///
/// The photo may be swapped for a new one of the seedling
/// ([takeAnotherPhoto], uploaded without identifying it); the name is
/// editable, the species read-only; the quantity goes from 1 to 99 and the
/// optional note up to 200 characters.
class NewListingViewModel extends ChangeNotifier with SafeNotify {
  NewListingViewModel({
    required this._listingRepository,
    required this._photoRepository,
    required this._photoPicker,
    required this.draft,
  }) : _photo = draft.photo,
       _commonName = draft.commonName;

  static const quantityMin = 1;
  static const quantityMax = 99;
  static const noteMaxLength = 200;
  static const nameMaxLength = 80;

  final ListingRepository _listingRepository;
  final PhotoRepository _photoRepository;
  final PhotoPicker _photoPicker;

  /// What the form started from.
  final ListingDraft draft;

  Photo _photo;
  Photo get photo => _photo;

  /// Whether the photo is still the one of the plant in Meu jardim.
  bool get isPlantPhoto => draft.plantId != null && _photo.id == draft.photo.id;

  ListingDraftSpecies? get species => draft.species;

  String _commonName;
  String get commonName => _commonName;

  String? _nameError;
  String? get nameError => _nameError;

  int _quantity = quantityMin;
  int get quantity => _quantity;
  bool get canDecrease => _quantity > quantityMin;
  bool get canIncrease => _quantity < quantityMax;

  String _note = '';
  String get note => _note;

  bool _isTakingPhoto = false;

  /// While a new photo is picked and sent.
  bool get isTakingPhoto => _isTakingPhoto;

  String? _photoError;
  String? get photoError => _photoError;

  bool _isPublishing = false;
  bool get isPublishing => _isPublishing;

  String? _publishError;
  String? get publishError => _publishError;

  /// Whether the last publish failed for lack of connection.
  bool _canRetryPublish = false;
  bool get canRetryPublish => _canRetryPublish;

  void updateName(String name) {
    _commonName = name;
    if (_nameError == null) return;
    _nameError = null;
    notify();
  }

  void updateNote(String note) {
    _note = note;
    notify();
  }

  void decrease() {
    if (!canDecrease) return;
    _quantity--;
    notify();
  }

  void increase() {
    if (!canIncrease) return;
    _quantity++;
    notify();
  }

  /// "Tirar outra foto da muda": picks a photo from [source] and sends it,
  /// without identifying it; it replaces the listing's photo. Cancelling
  /// keeps the current one.
  Future<void> takeAnotherPhoto(PhotoSource source) async {
    if (_isTakingPhoto) return;
    _isTakingPhoto = true;
    _photoError = null;
    notify();
    try {
      switch (await _photoPicker.pick(source)) {
        case Picked(:final photo):
          _photo = await _photoRepository.upload(photo);
        case PickCancelled():
          break;
        case CameraDenied():
          _photoError = PhotoViewModel.cameraDeniedMessage;
        case PickFailed():
          _photoError =
              'Não deu para abrir a câmera ou a galeria. Tente de novo.';
      }
    } on PhotoFailure catch (failure) {
      _photoError = photoFailureMessage(failure);
    } finally {
      _isTakingPhoto = false;
      notify();
    }
  }

  /// "Publicar anúncio".
  Future<PublishOutcome> publish() async {
    if (_isPublishing || _isTakingPhoto) return const NotPublished();
    final name = _commonName.trim();
    _nameError = name.isEmpty
        ? 'Dê um nome para a planta.'
        : name.length > nameMaxLength
        ? 'Use até $nameMaxLength caracteres.'
        : null;
    if (_nameError != null) {
      notify();
      return const NotPublished();
    }

    _isPublishing = true;
    _publishError = null;
    _canRetryPublish = false;
    notify();
    try {
      final listing = await _listingRepository.create(
        NewListing(
          photoId: _photo.id,
          commonName: name,
          quantity: _quantity,
          speciesId: draft.species?.id,
          plantId: draft.plantId,
          note: _note.trim(),
        ),
      );
      return Published(listing);
    } on ListingFailure catch (failure) {
      if (failure == ListingFailure.donationProfileRequired) {
        return const DonationProfileNeeded();
      }
      _publishError = listingFailureMessage(
        failure,
        notFound: 'Essa foto não está mais disponível. Tire outra foto.',
      );
      _canRetryPublish = failure == ListingFailure.noConnection;
      return const NotPublished();
    } finally {
      _isPublishing = false;
      notify();
    }
  }
}
