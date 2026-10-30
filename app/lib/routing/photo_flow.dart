part of 'router.dart';

/// The photo flow's dependencies and the screens it shares: the flow that
/// saves a new plant (under /identificar, [_identifyRoute]) and "Definir
/// espécie" (under the Tela da planta, [_gardenRoute]) differ only in where
/// each choice leads.
class _PhotoFlow {
  _PhotoFlow({
    required this.photoRepository,
    required this.photoPicker,
    required this.catalogRepository,
    required this.identificationRepository,
    required this.gardenRepository,
    required this.openUrl,
  });

  final PhotoRepository photoRepository;
  final PhotoPicker photoPicker;
  final CatalogRepository catalogRepository;
  final IdentificationRepository identificationRepository;
  final GardenRepository gardenRepository;
  final UrlOpener openUrl;

  /// The way into the photo flow from the camera button and the empty
  /// Jardim: asks camera or gallery over the current screen, then opens
  /// Foto. Closing the sheet stays where it was. ("Definir espécie" asks the
  /// same, then opens its own Foto.)
  Future<void> open(BuildContext context) async {
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

  Widget photoScreen(
    BuildContext context,
    GoRouterState state, {
    required Future<PhotoSource?> Function(Photo photo) onIdentify,
    required ValueChanged<Photo> onSearchByName,
  }) => ViewModelScope(
    create: () => PhotoViewModel(
      photoPicker: photoPicker,
      photoRepository: photoRepository,
    ),
    builder: (viewModel) => PhotoScreen(
      viewModel: viewModel,
      initialSource: Routes.photoSourceOf(state),
      onClose: () => context.pop(),
      onIdentify: onIdentify,
      onSearchByName: onSearchByName,
    ),
  );

  Widget candidatesScreen(
    BuildContext context,
    GoRouterState state, {
    required ValueChanged<SpeciesSummary> onSpecies,
    required VoidCallback onNoneOfThese,
    required VoidCallback onSearchByName,
    VoidCallback? onSaveNameOnly,
  }) {
    final extra = state.extra;
    return ViewModelScope(
      create: () => CandidatesViewModel(
        identificationRepository: identificationRepository,
        photoId: Routes.candidatesPhotoIdOf(state),
      )..identify(),
      builder: (viewModel) => CandidatesScreen(
        viewModel: viewModel,
        photo: extra is Photo ? extra : null,
        openUrl: openUrl,
        onSpecies: onSpecies,
        onNoneOfThese: onNoneOfThese,
        onTakeAnother: () async {
          final source = await showPhotoSourceSheet(context);
          if (source != null && context.mounted) context.pop(source);
        },
        onSearchByName: onSearchByName,
        onSaveNameOnly: onSaveNameOnly,
      ),
    );
  }

  Widget searchScreen({
    required ValueChanged<SpeciesSummary> onSpecies,
    ValueChanged<String>? onSaveNameOnly,
  }) => ViewModelScope(
    create: () => SearchViewModel(catalogRepository: catalogRepository),
    builder: (viewModel) => SearchScreen(
      viewModel: viewModel,
      onSpecies: onSpecies,
      onSaveNameOnly: onSaveNameOnly,
    ),
  );

  /// "Definir espécie": pushes [location] and, when it completes with the
  /// id of a species, closes the current screen with it too, so the id
  /// travels back to the Tela da planta. Otherwise the current screen stays.
  Future<void> passSpeciesBack(BuildContext context, String location) async {
    final speciesId = await context.push<String>(location);
    if (speciesId != null && context.mounted) context.pop(speciesId);
  }
}
