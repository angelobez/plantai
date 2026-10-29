import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'data/repositories/auth/auth_repository.dart';
import 'data/repositories/auth/auth_repository_remote.dart';
import 'data/repositories/photo/photo_repository.dart';
import 'data/repositories/photo/photo_repository_remote.dart';
import 'data/repositories/profile/profile_repository.dart';
import 'data/repositories/profile/profile_repository_remote.dart';
import 'data/services/api/api_client.dart';
import 'data/services/api/update_required.dart';
import 'data/services/google/google_id_tokens.dart';
import 'data/services/photo_picker/image_picker_photo_picker.dart';
import 'data/services/photo_picker/photo_picker.dart';
import 'data/services/session/session_store.dart';
import 'routing/router.dart';
import 'ui/core/themes/theme.dart';
import 'ui/core/url_opener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  final updateRequired = UpdateRequired();
  // Read before the first frame, so the router knows whether to open Login.
  final sessionStore = await SessionStore.load();
  final apiClient = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    appVersion: packageInfo.version,
    updateRequired: updateRequired,
    sessionStore: sessionStore,
  );
  final authRepository = AuthRepositoryRemote(
    apiClient: apiClient,
    sessionStore: sessionStore,
    googleIdTokens: GoogleSignInIdTokens(
      serverClientId: AppConfig.googleServerClientId,
    ),
  );
  final profileRepository = ProfileRepositoryRemote(apiClient: apiClient);
  final photoRepository = PhotoRepositoryRemote(apiClient: apiClient);

  runApp(
    // Repositories go here, built on the shared ApiClient.
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthRepository>.value(value: authRepository),
        Provider<ProfileRepository>.value(value: profileRepository),
        Provider<PhotoRepository>.value(value: photoRepository),
      ],
      child: PlantaiApp(
        updateRequired: updateRequired,
        authRepository: authRepository,
        profileRepository: profileRepository,
        photoRepository: photoRepository,
        photoPicker: ImagePickerPhotoPicker(),
      ),
    ),
  );
}

class PlantaiApp extends StatefulWidget {
  const PlantaiApp({
    super.key,
    required this.updateRequired,
    required this.authRepository,
    required this.profileRepository,
    required this.photoRepository,
    required this.photoPicker,
    this.openUrl = openExternally,
  });

  final UpdateRequired updateRequired;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final PhotoRepository photoRepository;
  final PhotoPicker photoPicker;
  final UrlOpener openUrl;

  @override
  State<PlantaiApp> createState() => _PlantaiAppState();
}

class _PlantaiAppState extends State<PlantaiApp> {
  late final _router = router(
    updateRequired: widget.updateRequired,
    authRepository: widget.authRepository,
    profileRepository: widget.profileRepository,
    photoRepository: widget.photoRepository,
    photoPicker: widget.photoPicker,
    openUrl: widget.openUrl,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PlantAí',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
