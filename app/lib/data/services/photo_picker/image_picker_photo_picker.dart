import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'photo_picker.dart';

/// [PhotoPicker] over the `image_picker` plugin. The plugin itself reduces the
/// photo, as the data spec asks ("Fotos: upload e entrega"), so a 5 MB photo
/// never leaves the phone.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  static const maxSide = 1600.0;
  static const imageQuality = 85;

  /// What the plugin's `PlatformException` says when the camera permission
  /// is refused.
  static const _cameraAccessDenied = 'camera_access_denied';

  final ImagePicker _picker;

  @override
  Future<PickResult> pick(PhotoSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: switch (source) {
          PhotoSource.camera => ImageSource.camera,
          PhotoSource.gallery => ImageSource.gallery,
        },
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: imageQuality,
        requestFullMetadata: false,
      );
    } on PlatformException catch (error) {
      if (error.code == _cameraAccessDenied) return const CameraDenied();
      return const PickFailed();
    }
    if (file == null) return const PickCancelled();
    return Picked(
      PickedPhoto(
        bytes: await file.readAsBytes(),
        filename: file.name.isEmpty ? 'photo.jpg' : file.name,
        contentType: file.mimeType ?? 'image/jpeg',
      ),
    );
  }
}
