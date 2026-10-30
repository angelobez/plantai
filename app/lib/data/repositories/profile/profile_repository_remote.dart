import '../../../domain/models/donation_profile.dart';
import '../../../domain/models/profile_failure.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/guard_api_call.dart';
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

  @override
  Future<UserProfile> updateDonationProfile(DonationProfile profile) => _guard(
    () => _apiClient.put('/v1/me/donation-profile', {
      'phone': profile.phone,
      'lat': profile.latitude,
      'lng': profile.longitude,
      'neighborhood': profile.neighborhood,
    }, UserProfile.fromJson),
  );

  static Future<T> _guard<T>(Future<T> Function() call) => guardApiCall(
    call,
    noConnection: ProfileFailure.noConnection,
    onError: (code) => switch (code) {
      ApiErrorCode.invalidPhone => ProfileFailure.invalidPhone,
      _ => ProfileFailure.unknown,
    },
  );
}
