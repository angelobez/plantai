import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/auth/auth_repository.dart';
import '../data/services/api/update_required.dart';
import '../ui/auth/email_login/view_models/email_login_view_model.dart';
import '../ui/auth/email_login/widgets/email_login_screen.dart';
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
import '../ui/tabs/widgets/tabs_shell.dart';
import '../ui/update_required/widgets/update_required_screen.dart';

abstract final class Routes {
  static const garden = '/jardim';
  static const nearby = '/perto';
  static const profile = '/perfil';
  static const identify = '/identificar';
  static const updateRequired = '/atualize';

  /// The entry screens all live under [login], so one prefix tells them apart.
  static const login = '/entrar';
  static const emailLogin = '$login/email';
  static const signup = '$login/criar-conta';
  static const verifyEmail = '$login/codigo';
  static const passwordReset = '$login/esqueci-a-senha';

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
  UrlOpener openUrl = openExternally,
}) {
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
        builder: (context, state) =>
            LoginScreen(onEmail: () => context.push(Routes.emailLogin)),
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
          onCamera: () => context.push(Routes.identify),
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
                builder: (context, state) => const TabPage(
                  body: ComingSoon(
                    icon: Icon(Icons.person_outline),
                    title: 'Seu perfil',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.identify,
        builder: (context, state) => Scaffold(
          appBar: AppBar(),
          body: const ComingSoon(
            icon: Icon(Icons.photo_camera_outlined),
            title: 'Identificar pela foto',
          ),
        ),
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
