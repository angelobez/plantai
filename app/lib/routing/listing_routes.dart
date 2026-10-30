part of 'router.dart';

/// What the [Routes.firstListing] route is pushed with.
class FirstListingArgs {
  const FirstListingArgs({this.profile, this.draft});

  /// Fills the fields, when the profile was read already.
  final UserProfile? profile;

  /// With it, saving goes on to the Novo anúncio of [draft], in place of
  /// the Primeiro anúncio. Without it, the route completes with the saved
  /// [UserProfile] (or null when the User goes back).
  final ListingDraft? draft;
}

/// Donation: the Por perto tab (with its inner tabs), the Primeiro anúncio
/// and the Novo anúncio, and the way in to a new listing ([donate]) that
/// other screens use.
class _ListingFlow {
  _ListingFlow({
    required this.listingRepository,
    required this.profileRepository,
    required this.photoRepository,
    required this.photoPicker,
    required this.locationService,
    required this.openUrl,
  });

  final ListingRepository listingRepository;
  final ProfileRepository profileRepository;
  final PhotoRepository photoRepository;
  final PhotoPicker photoPicker;
  final LocationService locationService;
  final UrlOpener openUrl;

  /// "Doar mudas" from anywhere: the Novo anúncio of [draft], with the
  /// Primeiro anúncio first when the User has no phone or no donation
  /// location yet.
  Future<void> donate(BuildContext context, ListingDraft draft) => startListing(
    context,
    profileRepository: profileRepository,
    onProfile: (profile) {
      if (!context.mounted) return;
      if (profile.hasDonationProfile) {
        context.push(Routes.newListing, extra: draft);
      } else {
        context.push(
          Routes.firstListing,
          extra: FirstListingArgs(profile: profile, draft: draft),
        );
      }
    },
  );

  /// "Doar mudas" in Meus anúncios: asks camera or gallery over it, then
  /// opens the photo flow under [Routes.donate]. Closing the sheet stays.
  Future<void> openPhotoFlow(BuildContext context) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
    await context.push(Routes.donateFrom(source));
  }

  /// The end of the photo flow under [Routes.donate]: the Novo anúncio of
  /// the photo with the name and the species chosen, with no plant. The
  /// flow stays under the form, so back from it is the last choice.
  late final donateEnd = _PhotoFlowEnd(
    saveLabel: 'Doar mudas',
    nameTitle: 'Nome da muda',
    needsPhoto: true,
    save: (context, choice) => donate(
      context,
      ListingDraft(
        photo: choice.photo!,
        commonName: choice.commonName,
        species: switch (choice.species) {
          final species? => ListingDraftSpecies(
            id: species.id,
            scientificName: species.scientificName,
          ),
          null => null,
        },
      ),
    ),
  );

  static void _selectTab(BuildContext context, ListingsTab tab) =>
      context.go(switch (tab) {
        ListingsTab.nearby => Routes.nearby,
        ListingsTab.mine => Routes.myListings,
      });

  /// The routes of the Por perto branch: one per inner tab, switched
  /// without a transition.
  List<RouteBase> tabRoutes() => [
    GoRoute(
      path: Routes.nearby,
      pageBuilder: (context, state) => NoTransitionPage(
        child: ListingsTabPage(
          selected: ListingsTab.nearby,
          onSelect: (tab) => _selectTab(context, tab),
          trailing: const HeaderPill(
            icon: Icons.location_on_outlined,
            label: 'até 30 km',
          ),
          body: const ComingSoon(
            icon: Icon(Icons.location_on_outlined),
            title: 'Mudas por perto',
          ),
        ),
      ),
    ),
    GoRoute(
      path: Routes.myListings,
      pageBuilder: (context, state) => NoTransitionPage(
        child: ViewModelScope(
          create: () =>
              MyListingsViewModel(listingRepository: listingRepository)..load(),
          builder: (viewModel) => MyListingsScreen(
            viewModel: viewModel,
            onSelectTab: (tab) => _selectTab(context, tab),
            onDonate: () => openPhotoFlow(context),
          ),
        ),
      ),
    ),
  ];

  /// The Primeiro anúncio and the Novo anúncio, over the whole shell.
  List<RouteBase> formRoutes() => [
    GoRoute(
      path: Routes.newListing,
      builder: (context, state) => ViewModelScope(
        create: () => NewListingViewModel(
          listingRepository: listingRepository,
          photoRepository: photoRepository,
          photoPicker: photoPicker,
          draft: state.extra! as ListingDraft,
        ),
        builder: (viewModel) => NewListingScreen(
          viewModel: viewModel,
          onPublished: (_) => context.go(Routes.myListings),
          onDonationProfileRequired: () async {
            final saved = await context.push<UserProfile>(
              Routes.firstListing,
              extra: const FirstListingArgs(),
            );
            return saved != null;
          },
        ),
      ),
    ),
    GoRoute(
      path: Routes.firstListing,
      builder: (context, state) {
        final args = state.extra as FirstListingArgs?;
        return ViewModelScope(
          create: () => DonationProfileViewModel(
            profileRepository: profileRepository,
            locationService: locationService,
            openUrl: openUrl,
            profile: args?.profile,
          ),
          builder: (viewModel) => DonationProfileScreen.firstListing(
            viewModel: viewModel,
            onSaved: (profile) {
              if (args?.draft case final draft?) {
                context.pushReplacement(Routes.newListing, extra: draft);
              } else {
                context.pop(profile);
              }
            },
          ),
        );
      },
    ),
  ];
}
