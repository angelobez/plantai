import 'package:plantai/data/services/google/google_id_tokens.dart';

/// Stands in for Google's account picker: answers [idToken] (null = the User
/// canceled), or throws [error] when set.
class FakeGoogleIdTokens implements GoogleIdTokens {
  FakeGoogleIdTokens({this.idToken = 'google-id-token'});

  String? idToken;
  GoogleIdTokenUnavailable? error;
  int requests = 0;

  @override
  Future<String?> request() async {
    requests++;
    final error = this.error;
    if (error != null) throw error;
    return idToken;
  }
}
