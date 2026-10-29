import 'package:flutter/foundation.dart';

import '../../../data/repositories/photo/photo_repository.dart';
import '../../../data/services/api/models/photo.dart';
import '../../../data/services/photo_picker/photo_picker.dart';
import '../../../domain/models/photo_failure.dart';

/// Foto: the photo the User took or picked, sent to the API at once while
/// they decide between "Identificar pela foto" and "Buscar pelo nome". Both
/// wait for [photo], the photo as the API stored it.
///
/// The flows that follow (identification, search) take [photo]; "Tirar outra"
/// is another [pick].
class PhotoViewModel extends ChangeNotifier {
  PhotoViewModel({required this._photoPicker, required this._photoRepository});

  final PhotoPicker _photoPicker;
  final PhotoRepository _photoRepository;

  /// The photo shown in the preview, from the phone; it stays when sending it
  /// fails, so "Tentar de novo" sends it again.
  PickedPhoto? _picked;
  PickedPhoto? get picked => _picked;

  /// The [picked] photo as the API stored it; null until it is sent.
  Photo? _photo;
  Photo? get photo => _photo;

  /// Whether the next steps can start: the photo is in the API.
  bool get isReady => _photo != null;

  bool _isPicking = false;
  bool get isPicking => _isPicking;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  /// Why the camera or the gallery gave no photo.
  String? _pickError;
  String? get pickError => _pickError;

  /// The camera permission was refused: the screen offers the gallery.
  bool _cameraDenied = false;
  bool get cameraDenied => _cameraDenied;

  /// Why the photo could not be sent.
  String? _uploadError;
  String? get uploadError => _uploadError;

  /// Whether sending the same photo again may work ("Tentar de novo").
  bool _canRetryUpload = false;
  bool get canRetryUpload => _canRetryUpload;

  /// Tells the uploads apart, so one that ends after another photo was
  /// picked changes nothing.
  int _uploadRun = 0;

  bool _disposed = false;

  /// Opens the camera or the gallery and sends the photo it gives.
  ///
  /// Returns whether the screen has something to show: false only when the
  /// User canceled before there was any photo, and the screen closes.
  /// Canceling is never an error; a later cancel keeps the photo there was.
  Future<bool> pick(PhotoSource source) async {
    _isPicking = true;
    _notify();
    final PickResult result;
    try {
      result = await _photoPicker.pick(source);
    } finally {
      _isPicking = false;
    }

    switch (result) {
      case Picked(:final photo):
        _cameraDenied = false;
        _pickError = null;
        _picked = photo;
        await _upload();
      case PickCancelled():
        _notify();
      case CameraDenied():
        _cameraDenied = true;
        _pickError = cameraDeniedMessage;
        _notify();
      case PickFailed():
        _cameraDenied = false;
        _pickError = 'Não deu para abrir a câmera ou a galeria. Tente de novo.';
        _notify();
    }
    return _picked != null || _pickError != null;
  }

  static const cameraDeniedMessage =
      'O PlantAí não tem acesso à câmera. Libere nas configurações do '
      'celular ou escolha uma foto da galeria.';

  /// "Tentar de novo": sends the same [picked] photo again.
  Future<void> retryUpload() async {
    if (_picked == null) return;
    await _upload();
  }

  Future<void> _upload() async {
    final picked = _picked;
    if (picked == null) return;
    final run = ++_uploadRun;
    _photo = null;
    _uploadError = null;
    _canRetryUpload = false;
    _isUploading = true;
    _notify();
    try {
      final photo = await _photoRepository.upload(picked);
      if (run != _uploadRun) return;
      _photo = photo;
    } on PhotoFailure catch (failure) {
      if (run != _uploadRun) return;
      _uploadError = _message(failure);
      _canRetryUpload =
          failure == PhotoFailure.noConnection ||
          failure == PhotoFailure.unknown;
    } finally {
      if (run == _uploadRun) {
        _isUploading = false;
        _notify();
      }
    }
  }

  static String _message(PhotoFailure failure) => switch (failure) {
    PhotoFailure.noConnection =>
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    PhotoFailure.dailyLimit =>
      'Você já enviou 50 fotos hoje, o limite do dia. Amanhã tem mais.',
    PhotoFailure.notAnImage =>
      'Não deu para ler esta foto. Tire ou escolha outra foto.',
    PhotoFailure.unknown => 'Algo deu errado. Tente de novo.',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
