import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/services/api/update_required.dart';
import '../ui/core/url_opener.dart';
import '../ui/core/widgets/coming_soon.dart';
import '../ui/core/widgets/leaf_icon.dart';
import '../ui/core/widgets/tab_page.dart';
import '../ui/tabs/widgets/tabs_shell.dart';
import '../ui/update_required/widgets/update_required_screen.dart';

abstract final class Routes {
  static const garden = '/jardim';
  static const nearby = '/perto';
  static const profile = '/perfil';
  static const identify = '/identificar';
  static const updateRequired = '/atualize';
}

/// The app's routes.
///
/// [redirect] runs its rules in order; the first one that answers a location
/// wins. New global rules (such as "no session goes to Login") go in that
/// list, and their notifier in `refreshListenable`.
GoRouter router({
  required UpdateRequired updateRequired,
  UrlOpener openUrl = openExternally,
}) {
  final rules = <String? Function(GoRouterState state)>[
    // A 426 on any call: everything goes to "Atualize o PlantAí".
    (state) => updateRequired.isRequired ? Routes.updateRequired : null,
  ];

  return GoRouter(
    initialLocation: Routes.nearby,
    refreshListenable: updateRequired,
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
