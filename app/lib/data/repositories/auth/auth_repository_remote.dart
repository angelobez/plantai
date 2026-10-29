import '../../../domain/models/auth_failure.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/models/auth_tokens.dart';
import '../../services/google/google_id_tokens.dart';
import '../../services/session/session_store.dart';
import 'auth_repository.dart';

/// [AuthRepository] backed by the API's `/v1/auth` routes, with the tokens in
/// the [SessionStore]. It is where the API's errors become an [AuthFailure].
class AuthRepositoryRemote extends AuthRepository {
  AuthRepositoryRemote({
    required this._apiClient,
    required this._sessionStore,
    this._googleIdTokens,
  }) {
    _sessionStore.addListener(notifyListeners);
  }

  final ApiClient _apiClient;
  final SessionStore _sessionStore;

  /// Null only where Google is never used (tests of the other flows).
  final GoogleIdTokens? _googleIdTokens;

  String? _pendingEmail;

  /// How to ask for another code: the request that sent the last one.
  Future<void> Function()? _resend;

  @override
  bool get isSignedIn => _sessionStore.session != null;

  @override
  String? get pendingEmail => _pendingEmail;

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    Future<void> send() => _guard(
      () => _apiClient.postWithoutBody('/v1/auth/signup', {
        'name': name,
        'email': email,
        'password': password,
      }),
    );
    await send();
    _pendingEmail = email;
    _resend = send;
  }

  @override
  Future<void> resendCode() async {
    final resend = _resend;
    if (resend == null) throw StateError('No code was sent yet');
    await resend();
  }

  @override
  Future<void> verifyEmail(String code) async {
    final email = _pendingEmail;
    if (email == null) throw StateError('No e-mail is waiting for a code');
    final tokens = await _guard(
      () => _apiClient.post('/v1/auth/verify-email', {
        'email': email,
        'code': code,
      }, AuthTokens.fromJson),
    );
    await _startSession(tokens);
  }

  @override
  Future<void> signInWithGoogle() async {
    final google = _googleIdTokens;
    if (google == null) throw StateError('No GoogleIdTokens was given');
    final String? idToken;
    try {
      idToken = await google.request();
    } on GoogleIdTokenUnavailable {
      throw AuthFailure.googleUnavailable;
    }
    if (idToken == null) return; // Canceled.
    final tokens = await _guard(
      () => _apiClient.post('/v1/auth/google', {
        'idToken': idToken,
      }, AuthTokens.fromJson),
    );
    await _startSession(tokens);
  }

  Future<void> _startSession(AuthTokens tokens) async {
    _pendingEmail = null;
    _resend = null;
    await _sessionStore.save(
      Session(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      ),
    );
  }

  /// Runs [call], turning what the API answers into an [AuthFailure].
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiConnectionException {
      throw AuthFailure.noConnection;
    } on ApiException catch (error) {
      throw switch (error.code) {
        ApiErrorCode.invalidCode => AuthFailure.invalidCode,
        ApiErrorCode.invalidCredentials => AuthFailure.invalidCredentials,
        ApiErrorCode.emailNotVerified => AuthFailure.emailNotVerified,
        ApiErrorCode.googleAccountLinkRefused =>
          AuthFailure.googleAccountLinkRefused,
        ApiErrorCode.tooManyRequests => AuthFailure.tooManyRequests,
        ApiErrorCode.validationFailed => AuthFailure.validationFailed,
        ApiErrorCode.appUpdateRequired => AuthFailure.updateRequired,
        _ => AuthFailure.unknown,
      };
    }
  }

  @override
  void dispose() {
    _sessionStore.removeListener(notifyListeners);
    super.dispose();
  }
}
