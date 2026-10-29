import '../../../domain/models/photo_failure.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/guard_api_call.dart';
import '../../services/api/models/photo.dart';
import '../../services/photo_picker/photo_picker.dart';
import 'photo_repository.dart';

/// [PhotoRepository] backed by the API's `/v1/photos`.
class PhotoRepositoryRemote implements PhotoRepository {
  PhotoRepositoryRemote({required this._apiClient});

  final ApiClient _apiClient;

  @override
  Future<Photo> upload(PickedPhoto photo) => _guard(
    () => _apiClient.postMultipart('/v1/photos', {
      'file': UploadFile(
        bytes: photo.bytes,
        filename: photo.filename,
        contentType: photo.contentType,
      ),
    }, Photo.fromJson),
  );

  static Future<T> _guard<T>(Future<T> Function() call) => guardApiCall(
    call,
    noConnection: PhotoFailure.noConnection,
    onError: (code) => switch (code) {
      ApiErrorCode.photoDailyLimit => PhotoFailure.dailyLimit,
      ApiErrorCode.validationFailed => PhotoFailure.notAnImage,
      _ => PhotoFailure.unknown,
    },
  );
}
