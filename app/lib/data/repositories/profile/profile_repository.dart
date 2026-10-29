import '../../services/api/models/user_profile.dart';

/// The signed-in User's own profile (`/v1/me`).
///
/// Every method throws a `ProfileFailure` when it fails.
abstract class ProfileRepository {
  Future<UserProfile> fetchProfile();

  /// Changes the name and returns the profile as the API saved it.
  Future<UserProfile> updateName(String name);
}
