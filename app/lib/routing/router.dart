import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/auth/auth_repository.dart';
import '../data/repositories/photo/photo_repository.dart';
import '../data/repositories/profile/profile_repository.dart';
import '../data/services/api/update_required.dart';
import '../data/services/photo_picker/photo_picker.dart';
import '../ui/about/widgets/about_screen.dart';
import '../ui/auth/email_login/view_models/email_login_view_model.dart';
import '../ui/auth/email_login/widgets/email_login_screen.dart';
import '../ui/auth/login/view_models/login_view_model.dart';
import '../ui/auth/login/widgets/login_screen.dart';
import '../ui/auth/password_reset/view_models/password_reset_view_model.dart';
import '../ui/auth/password_reset/widgets/password_reset_screen.dart';
import '../ui/auth/signup/view_models/signup_view_model.dart';
import '../ui/auth/signup/widgets/signup_screen.dart';
import '../ui/auth/verify_email/view_models/verify_email_view_model.dart';
import '../ui/auth/verify_email/widgets/verify_email_screen.dart';
import '../ui/core/url_opener.dart';
import '../ui/core/widgets/coming_soon.dart';
import '../ui/core/widgets/leaf_icon.dart';
import '../ui/core/widgets/tab_page.dart';
import '../ui/core/widgets/view_model_scope.dart';
import '../ui/photo/view_models/photo_view_model.dart';
import '../ui/photo/widgets/photo_screen.dart';
import '../ui/photo/widgets/photo_source_sheet.dart';
import '../ui/profile/view_models/profile_view_model.dart';
import '../ui/profile/widgets/profile_screen.dart';
import '../ui/tabs/widgets/tabs_shell.dart';
import '../ui/update_required/widgets/update_required_screen.dart';

abstract final class Routes {
  static const garden = '/jardim';
  static const nearby = '/perto';
  static const profile = '/perfil';

  /// Foto, the start of the flow to identify a plant. Takes the source of
  /// the first photo in the `fonte` query parameter ([identifyFrom]).
  static const identify = '/identificar';
  static const about = '/sobre';
  static const updateRequired = '/atualize';

  /// The entry screens all live under [login], so one prefix tells them apart.
  static const login = '/entrar';
  static const emailLogin = '$login/email';
  static const signup = '$login/criar-conta';
  static const verifyEmail = '$login/codigo';
  static const passwordReset = '$login/esqueci-a-senha';

  /// Foto, opening the camera or the gallery as it appears.
  static String identifyFrom(PhotoSource source) => Uri(
    path: identify,
    queryParameters: {_photoSourceParam: source.name},
  ).toString();

  static const _photoSourceParam = 'fonte';

  /// The source in a [identifyFrom] location; the gallery when there is none,
  /// since it needs no permission.
  static PhotoSource photoSourceOf(GoRouterState state) =>
      PhotoSource.values
          .asNameMap()[state.uri.queryParameters[_photoSourceParam]] ??
      PhotoSource.gallery;

  static bool isEntry(String location) =>
      location == login || location.startsWith('$login/');
}

/// The app's routes.
///
/// [redirect] runs its rules in order; the first one that answers a location
/// wins: "Atualize o PlantAí" first, then the session (Login without one,
/// never back to the entry screens with one). New global rules go in that
/// list, and their notifier in `refreshListenable`.
GoRouter router({
  required UpdateRequired updateRequired,
  required AuthRepository authRepository,
  required ProfileRepository profileRepository,
  required PhotoRepository photoRepository,
  required PhotoPicker photoPicker,
  UrlOpener openUrl = openExternally,
}) {
  /// The way into the photo flow from anywhere (the camera button, and later
  /// the empty Jardim and "Definir espécie"): asks camera or gallery over the
  /// current screen, then opens Foto. Closing the sheet stays where it was.
  Future<void> openPhotoFlow(BuildContext context) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
    await context.push(Routes.identifyFrom(source));
  }

  final rules = <String? Function(GoRouterState state)>[
    // A 426 on any call: everything goes to "Atualize o PlantAí".
    (state) => updateRequired.isRequired ? Routes.updateRequired : null,
    // No session: only the entry screens. With one: never back to them.
    (state) {
      final location = state.matchedLocation;
      if (authRepository.isSignedIn) {
        return Routes.isEntry(location) ? Routes.nearby : null;
      }
      if (!Routes.isEntry(location)) return Routes.login;
      // The code screen needs the e-mail that is waiting for it.
      if (location == Routes.verifyEmail &&
          authRepository.pendingEmail == null) {
        return Routes.login;
      }
      return null;
    },
  ];

  return GoRouter(
    initialLocation: Routes.nearby,
    refreshListenable: Listenable.merge([updateRequired, authRepository]),
    redirect: (context, state) {
      for (final rule in rules) {
        final location = rule(state);
        if (location != null) {
          return location == state.matchedLocation ? null : location;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => ViewModelScope(
          create: () => LoginViewModel(authRepository: authRepository),
          builder: (viewModel) => LoginScreen(
            viewModel: viewModel,
            onEmail: () => context.push(Routes.emailLogin),
          ),
        ),
        routes: [
          GoRoute(
            path: _child(Routes.emailLogin),
            builder: (context, state) => ViewModelScope(
              create: () => EmailLoginViewModel(authRepository: authRepository),
              builder: (viewModel) => EmailLoginScreen(
                viewModel: viewModel,
                onVerifyEmail: () => context.push(Routes.verifyEmail),
                onSignup: () => context.push(Routes.signup),
                onForgotPassword: () => context.push(Routes.passwordReset),
              ),
            ),
          ),
          GoRoute(
            path: _child(Routes.signup),
            builder: (context, state) => ViewModelScope(
              create: () => SignupViewModel(authRepository: authRepository),
              builder: (viewModel) => SignupScreen(
                viewModel: viewModel,
                onCodeSent: () => context.push(Routes.verifyEmail),
              ),
            ),
          ),
          GoRoute(
            path: _child(Routes.verifyEmail),
            builder: (context, state) => ViewModelScope(
              create: () =>
                  VerifyEmailViewModel(authRepository: authRepository),
              builder: (viewModel) => VerifyEmailScreen(viewModel: viewModel),
            ),
          ),
          GoRoute(
            path: _child(Routes.passwordReset),
            builder: (context, state) => ViewModelScope(
              create: () =>
                  PasswordResetViewModel(authRepository: authRepository),
              builder: (viewModel) => PasswordResetScreen(viewModel: viewModel),
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => TabsShell(
          navigationShell: navigationShell,
          onCamera: () => openPhotoFlow(context),
        ),
        // Same order as AppTab.
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.garden,
                builder: (context, state) => const TabPage(
                  body: ComingSoon(icon: LeafIcon(), title: 'Meu jardim'),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.nearby,
                builder: (context, state) => const TabPage(
                  body: ComingSoon(
                    icon: Icon(Icons.location_on_outlined),
                    title: 'Mudas por perto',
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => ViewModelScope(
                  create: () => ProfileViewModel(
                    profileRepository: profileRepository,
                    authRepository: authRepository,
                  )..load(),
                  builder: (viewModel) => ProfileScreen(
                    viewModel: viewModel,
                    onAbout: () => context.push(Routes.about),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      // The next screens of the flow ("Buscar pelo nome", candidates) go in
      // as its child routes and get the uploaded photo from the callbacks.
      GoRoute(
        path: Routes.identify,
        builder: (context, state) => ViewModelScope(
          create: () => PhotoViewModel(
            photoPicker: photoPicker,
            photoRepository: photoRepository,
          ),
          builder: (viewModel) => PhotoScreen(
            viewModel: viewModel,
            initialSource: Routes.photoSourceOf(state),
            onClose: () => context.pop(),
          ),
        ),
      ),
      GoRoute(
        path: Routes.about,
        builder: (context, state) => AboutScreen(openUrl: openUrl),
      ),
      GoRoute(
        path: Routes.updateRequired,
        builder: (context, state) => UpdateRequiredScreen(openUrl: openUrl),
      ),
    ],
  );
}

/// The path of an entry screen relative to [Routes.login], as a child route.
String _child(String location) => location.substring(Routes.login.length + 1);
