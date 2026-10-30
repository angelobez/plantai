import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/auth/auth_repository.dart';
import '../data/repositories/catalog/catalog_repository.dart';
import '../data/repositories/garden/garden_repository.dart';
import '../data/repositories/identification/identification_repository.dart';
import '../data/repositories/listing/listing_repository.dart';
import '../data/repositories/photo/photo_repository.dart';
import '../data/repositories/profile/profile_repository.dart';
import '../data/services/api/models/user_profile.dart';
import '../data/services/location/location_service.dart';
import '../data/services/api/models/photo.dart';
import '../data/services/api/models/species_summary.dart';
import '../data/services/api/update_required.dart';
import '../data/services/photo_picker/photo_picker.dart';
import '../domain/models/listing_draft.dart';
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
import '../ui/core/widgets/view_model_scope.dart';
import '../ui/garden/view_models/garden_view_model.dart';
import '../ui/garden/view_models/plant_view_model.dart';
import '../ui/garden/widgets/garden_screen.dart';
import '../ui/garden/widgets/plant_name_dialog.dart';
import '../ui/garden/widgets/plant_screen.dart';
import '../ui/garden/widgets/save_plant.dart';
import '../ui/identification/view_models/candidates_view_model.dart';
import '../ui/listings/view_models/my_listings_view_model.dart';
import '../ui/listings/view_models/new_listing_view_model.dart';
import '../ui/listings/widgets/listings_tab_page.dart';
import '../ui/listings/widgets/my_listings_screen.dart';
import '../ui/listings/widgets/new_listing_screen.dart';
import '../ui/listings/widgets/start_listing.dart';
import '../ui/identification/widgets/candidates_screen.dart';
import '../ui/photo/view_models/photo_view_model.dart';
import '../ui/photo/widgets/photo_screen.dart';
import '../ui/photo/widgets/photo_source_sheet.dart';
import '../ui/donation_profile/view_models/donation_profile_view_model.dart';
import '../ui/donation_profile/widgets/donation_profile_screen.dart';
import '../ui/profile/view_models/profile_view_model.dart';
import '../ui/profile/widgets/profile_screen.dart';
import '../ui/tabs/widgets/tabs_shell.dart';
import '../ui/update_required/widgets/update_required_screen.dart';

part 'entry_routes.dart';
part 'garden_routes.dart';
part 'identify_routes.dart';
part 'listing_routes.dart';
part 'photo_flow.dart';

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

  /// "Definir espécie" of the plant [plantId] by the Busca, over the Tela da
  /// planta. Pushed for a result: the id of the chosen species, or null.
  static String defineSpeciesSearch(String plantId) =>
      '${plant(plantId)}/$_defineSpeciesPath/$_searchPath';

  /// "Definir espécie" of the plant [plantId] by a new photo from [source]:
  /// Foto, then [defineSpeciesCandidates]. Pushed for a result, as
  /// [defineSpeciesSearch]. The new photo identifies the species but never
  /// becomes the plant's.
  static String defineSpeciesPhoto(String plantId, PhotoSource source) => Uri(
    path: '${plant(plantId)}/$_defineSpeciesPath/$_photoPath',
    queryParameters: {_photoSourceParam: source.name},
  ).toString();

  /// Candidatos of [defineSpeciesPhoto], for the photo [photoId]. Pushed
  /// with the [Photo] as `extra`; completes with the chosen species' id, or
  /// with the source of another photo ("Tirar outra foto").
  static String defineSpeciesCandidates(String plantId, String photoId) =>
      '${plant(plantId)}/$_defineSpeciesPath/$_photoPath/'
      '$_candidatesPath/${Uri.encodeComponent(photoId)}';

  static const _defineSpeciesPath = 'especie';
  static const _photoPath = 'foto';

  /// The Por perto tab, on its "Por perto" inner tab.
  static const nearby = '/perto';

  /// The Por perto tab, on its "Meus anúncios" inner tab.
  static const myListings = '/meus-anuncios';

  /// Novo anúncio, over the whole shell. Pushed with the [ListingDraft] it
  /// starts from as `extra`; publishing goes to [myListings].
  static const newListing = '/anunciar';

  /// Primeiro anúncio: the donation profile before a first listing, over
  /// the whole shell. Pushed with a [FirstListingArgs] as `extra`.
  static const firstListing = '/antes-de-doar';
  static const profile = '/perfil';

  /// The phone and the donation location, over Perfil. Pushed with the
  /// [UserProfile] as `extra` (to fill the fields); completes with the
  /// profile as saved, or null when the User goes back.
  static const donationProfile = '$profile/$_donationProfilePath';
  static const _donationProfilePath = 'doacao';

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
  required LocationService locationService,
  required ListingRepository listingRepository,
  UrlOpener openUrl = openExternally,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final flow = _PhotoFlow(
    photoRepository: photoRepository,
    photoPicker: photoPicker,
    catalogRepository: catalogRepository,
    identificationRepository: identificationRepository,
    gardenRepository: gardenRepository,
    openUrl: openUrl,
  );
  final listingFlow = _ListingFlow(
    listingRepository: listingRepository,
    profileRepository: profileRepository,
    photoRepository: photoRepository,
    photoPicker: photoPicker,
    locationService: locationService,
    openUrl: openUrl,
  );

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
      _entryRoute(authRepository),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => TabsShell(
          navigationShell: navigationShell,
          onCamera: () => flow.open(context),
        ),
        // Same order as AppTab.
        branches: [
          StatefulShellBranch(
            routes: [
              _gardenRoute(
                flow,
                listingFlow,
                rootNavigatorKey: rootNavigatorKey,
              ),
            ],
          ),
          StatefulShellBranch(routes: listingFlow.tabRoutes()),
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
                    onEditDonationProfile: (profile) async {
                      final saved = await context.push<UserProfile>(
                        Routes.donationProfile,
                        extra: profile,
                      );
                      if (saved != null) viewModel.showProfile(saved);
                    },
                  ),
                ),
                routes: [
                  // Over the whole shell, like the other forms.
                  GoRoute(
                    parentNavigatorKey: rootNavigatorKey,
                    path: Routes._donationProfilePath,
                    builder: (context, state) => ViewModelScope(
                      create: () => DonationProfileViewModel(
                        profileRepository: profileRepository,
                        locationService: locationService,
                        openUrl: openUrl,
                        profile: state.extra as UserProfile?,
                      ),
                      builder: (viewModel) => DonationProfileScreen.profile(
                        viewModel: viewModel,
                        onSaved: (profile) => context.pop(profile),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      _identifyRoute(flow),
      ...listingFlow.formRoutes(),
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
