import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/auth/auth_repository.dart';
import '../data/repositories/catalog/catalog_repository.dart';
import '../data/repositories/garden/garden_repository.dart';
import '../data/repositories/identification/identification_repository.dart';
import '../data/repositories/photo/photo_repository.dart';
import '../data/repositories/profile/profile_repository.dart';
import '../data/services/api/models/photo.dart';
import '../data/services/api/update_required.dart';
import '../data/services/photo_picker/photo_picker.dart';
import '../domain/models/new_plant.dart';
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
import '../ui/catalog/view_models/search_view_model.dart';
import '../ui/catalog/view_models/species_view_model.dart';
import '../ui/catalog/widgets/search_screen.dart';
import '../ui/catalog/widgets/species_screen.dart';
import '../ui/core/url_opener.dart';
import '../ui/core/widgets/coming_soon.dart';
import '../ui/core/widgets/tab_page.dart';
import '../ui/core/widgets/view_model_scope.dart';
import '../ui/garden/view_models/garden_view_model.dart';
import '../ui/garden/view_models/plant_view_model.dart';
import '../ui/garden/widgets/garden_screen.dart';
import '../ui/garden/widgets/plant_name_dialog.dart';
import '../ui/garden/widgets/plant_screen.dart';
import '../ui/garden/widgets/save_plant.dart';
import '../ui/identification/view_models/candidates_view_model.dart';
import '../ui/identification/widgets/candidates_screen.dart';
import '../ui/photo/view_models/photo_view_model.dart';
import '../ui/photo/widgets/photo_screen.dart';
import '../ui/photo/widgets/photo_source_sheet.dart';
import '../ui/profile/view_models/profile_view_model.dart';
import '../ui/profile/widgets/profile_screen.dart';
import '../ui/tabs/widgets/tabs_shell.dart';
import '../ui/update_required/widgets/update_required_screen.dart';

abstract final class Routes {
  static const garden = '/jardim';

  /// Tela da planta, over the Jardim tab (back goes to the list), without
  /// the bottom bar.
  static String plant(String plantId) =>
      '$garden/$_plantPath/${Uri.encodeComponent(plantId)}';

  static const _plantPath = 'planta';
  static const _plantIdParam = 'id';

  /// The plant of a [plant] location.
  static String plantIdOf(GoRouterState state) =>
      state.pathParameters[_plantIdParam]!;

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

  /// Busca no Catálogo, inside the photo flow. [photoId] is the photo already
  /// sent, which "Salvar só com o nome" saves with the plant.
  static String searchByName({String? photoId}) =>
      _withPhoto('$identify/$_searchPath', photoId);

  /// Tela da espécie, inside the photo flow, with the photo "Salvar no meu
  /// jardim" saves with the plant ([photoId]), when there is one.
  static String species(String speciesId, {String? photoId}) => _withPhoto(
    '$identify/$_speciesPath/${Uri.encodeComponent(speciesId)}',
    photoId,
  );

  /// Candidatos, inside the photo flow: identifies the photo [photoId],
  /// already sent, and leads to Candidatos, Foto não reconhecida or Limite
  /// diário. Pushed with the [Photo] as `extra`, for its thumbnail; the
  /// push completes with the source of another photo when the User asks for
  /// one ("Tirar outra foto").
  static String candidates(String photoId) =>
      '$identify/$_candidatesPath/${Uri.encodeComponent(photoId)}';

  static const _candidatesPath = 'candidatos';
  static const _searchPath = 'busca';
  static const _speciesPath = 'especie';
  static const _speciesIdParam = 'id';
  static const _photoIdParam = 'foto';

  /// The photo of a [searchByName] or [species] location, if any.
  static String? photoIdOf(GoRouterState state) =>
      state.uri.queryParameters[_photoIdParam];

  /// The photo of a [candidates] location.
  static String candidatesPhotoIdOf(GoRouterState state) =>
      state.pathParameters[_photoIdParam]!;

  /// The species of a [species] location.
  static String speciesIdOf(GoRouterState state) =>
      state.pathParameters[_speciesIdParam]!;

  static String _withPhoto(String path, String? photoId) => Uri(
    path: path,
    queryParameters: photoId == null ? null : {_photoIdParam: photoId},
  ).toString();

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
  required CatalogRepository catalogRepository,
  required IdentificationRepository identificationRepository,
  required GardenRepository gardenRepository,
  UrlOpener openUrl = openExternally,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  /// The way into the photo flow from anywhere (the camera button, the empty
  /// Jardim, and later "Definir espécie"): asks camera or gallery over the
  /// current screen, then opens Foto. Closing the sheet stays where it was.
  Future<void> openPhotoFlow(BuildContext context) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
    await context.push(Routes.identifyFrom(source));
  }

  /// Saves the plant from the photo flow, then opens it: the flow leaves the
  /// stack, and back from the Tela da planta is the Jardim tab.
  void saveAndOpen(BuildContext context, NewPlant plant) => savePlant(
    context,
    gardenRepository: gardenRepository,
    plant: plant,
    onSaved: (saved) {
      if (context.mounted) context.go(Routes.plant(saved.id));
    },
  );

  /// "Salvar só com o nome" where there is no name yet (Foto não reconhecida,
  /// Limite diário): asks it first.
  Future<void> askNameAndSave(BuildContext context, String photoId) async {
    final name = await showPlantNameDialog(context);
    if (name == null || !context.mounted) return;
    saveAndOpen(context, NewPlant(photoId: photoId, commonName: name));
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
    navigatorKey: rootNavigatorKey,
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
                builder: (context, state) => ViewModelScope(
                  create: () =>
                      GardenViewModel(gardenRepository: gardenRepository)
                        ..load(),
                  builder: (viewModel) => GardenScreen(
                    viewModel: viewModel,
                    onPlant: (plant) => context.push(Routes.plant(plant.id)),
                    onIdentify: () => openPhotoFlow(context),
                  ),
                ),
                routes: [
                  // Over the whole shell: the Tela da planta has no bottom
                  // bar, and back is the list.
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: '${Routes._plantPath}/:${Routes._plantIdParam}',
                    builder: (context, state) => ViewModelScope(
                      create: () => PlantViewModel(
                        gardenRepository: gardenRepository,
                        plantId: Routes.plantIdOf(state),
                      )..load(),
                      builder: (viewModel) => PlantScreen(
                        viewModel: viewModel,
                        openUrl: openUrl,
                        // The list already left out the plant (the
                        // repository told it).
                        onRemoved: () => context.go(Routes.garden),
                      ),
                    ),
                  ),
                ],
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
      // The next screens of the flow (Candidatos, Busca, Tela da espécie) are
      // its child routes, pushed over Foto, so going back finds the same
      // photo. They get the uploaded photo's id in the query.
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
            onIdentify: (photo) => context.push<PhotoSource>(
              Routes.candidates(photo.id),
              extra: photo,
            ),
            onSearchByName: (photo) =>
                context.push(Routes.searchByName(photoId: photo.id)),
          ),
        ),
        routes: [
          GoRoute(
            path: '${Routes._candidatesPath}/:${Routes._photoIdParam}',
            builder: (context, state) {
              final photoId = Routes.candidatesPhotoIdOf(state);
              final extra = state.extra;
              return ViewModelScope(
                create: () => CandidatesViewModel(
                  identificationRepository: identificationRepository,
                  photoId: photoId,
                )..identify(),
                builder: (viewModel) => CandidatesScreen(
                  viewModel: viewModel,
                  photo: extra is Photo ? extra : null,
                  openUrl: openUrl,
                  // The choice is made: Candidatos leaves the stack, and
                  // back from the next screen is Foto.
                  onSpecies: (species) => context.pushReplacement(
                    Routes.species(species.id, photoId: photoId),
                  ),
                  onNoneOfThese: () => context.pushReplacement(
                    Routes.searchByName(photoId: photoId),
                  ),
                  onTakeAnother: () async {
                    final source = await showPhotoSourceSheet(context);
                    if (source != null && context.mounted) {
                      context.pop(source);
                    }
                  },
                  onSearchByName: () =>
                      context.push(Routes.searchByName(photoId: photoId)),
                  onSaveNameOnly: () => askNameAndSave(context, photoId),
                ),
              );
            },
          ),
          GoRoute(
            path: Routes._searchPath,
            builder: (context, state) {
              final photoId = Routes.photoIdOf(state);
              return ViewModelScope(
                create: () =>
                    SearchViewModel(catalogRepository: catalogRepository),
                builder: (viewModel) => SearchScreen(
                  viewModel: viewModel,
                  onSpecies: (species) => context.push(
                    Routes.species(species.id, photoId: photoId),
                  ),
                  onSaveNameOnly: photoId == null
                      ? null
                      : (name) => saveAndOpen(
                          context,
                          NewPlant(photoId: photoId, commonName: name),
                        ),
                ),
              );
            },
          ),
          GoRoute(
            path: '${Routes._speciesPath}/:${Routes._speciesIdParam}',
            builder: (context, state) {
              final photoId = Routes.photoIdOf(state);
              return ViewModelScope(
                create: () => SpeciesViewModel(
                  catalogRepository: catalogRepository,
                  speciesId: Routes.speciesIdOf(state),
                )..load(),
                builder: (viewModel) => SpeciesScreen(
                  viewModel: viewModel,
                  openUrl: openUrl,
                  onSaveToGarden: photoId == null
                      ? null
                      : (species) => saveAndOpen(
                          context,
                          NewPlant(
                            photoId: photoId,
                            commonName: species.commonName,
                            speciesId: species.id,
                          ),
                        ),
                ),
              );
            },
          ),
        ],
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
