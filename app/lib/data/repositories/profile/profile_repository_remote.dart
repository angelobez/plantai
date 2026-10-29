import '../../../domain/models/profile_failure.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/models/user_profile.dart';
import 'profile_repository.dart';

/// [ProfileRepository] backed by the API's `/v1/me`.
class ProfileRepositoryRemote implements ProfileRepository {
  ProfileRepositoryRemote({required this._apiClient});

  final ApiClient _apiClient;

  @override
  Future<UserProfile> fetchProfile() =>
      _guard(() => _apiClient.get('/v1/me', UserProfile.fromJson));

  @override
  Future<UserProfile> updateName(String name) => _guard(
    () => _apiClient.patch('/v1/me', {'name': name}, UserProfile.fromJson),
  );

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiConnectionException {
      throw ProfileFailure.noConnection;
    } on ApiException {
      throw ProfileFailure.unknown;
    }
  }
}
