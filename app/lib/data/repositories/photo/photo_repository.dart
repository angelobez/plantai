import '../../services/api/models/photo.dart';
import '../../services/photo_picker/photo_picker.dart';

/// The User's photos in the API (`/v1/photos`).
///
/// Every method throws a `PhotoFailure` when it fails.
abstract class PhotoRepository {
  /// Sends [photo] and returns it as the API stored it: upright, without
  /// metadata, tagged as not used yet.
  Future<Photo> upload(PickedPhoto photo);
}
