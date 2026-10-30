import 'dart:typed_data';

/// Where the User takes the photo from.
enum PhotoSource { camera, gallery }

/// A photo the User took or picked, already reduced by the picker (about
/// 1600 px on the longer side, JPEG at quality 85).
class PickedPhoto {
  const PickedPhoto({
    required this.bytes,
    required this.filename,
    this.contentType = 'image/jpeg',
  });

  final Uint8List bytes;
  final String filename;

  /// The media type sent with the upload.
  final String contentType;
}

/// What came out of [PhotoPicker.pick].
sealed class PickResult {
  const PickResult();
}

/// The User took or picked [photo].
final class Picked extends PickResult {
  const Picked(this.photo);

  final PickedPhoto photo;
}

/// The User closed the camera or the gallery without a photo. Not an error.
final class PickCancelled extends PickResult {
  const PickCancelled();
}

/// The User refused (now or before) the camera permission. The gallery still
/// works.
final class CameraDenied extends PickResult {
  const CameraDenied();
}

/// The camera or the gallery could not be opened (a plugin error).
final class PickFailed extends PickResult {
  const PickFailed();
}

/// The port to the phone's camera and gallery: one photo at a time. The real
/// one is `ImagePickerPhotoPicker`; tests use a fake that answers what the
/// test says.
///
/// The camera permission is asked only by [pick] with [PhotoSource.camera],
/// never before.
abstract class PhotoPicker {
  Future<PickResult> pick(PhotoSource source);
}
