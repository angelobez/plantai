part of 'router.dart';

/// What the User chose at the end of a photo flow: the photo sent, with the
/// species from the Tela da espécie, or only a name ("Salvar só com o
/// nome").
class _PhotoFlowChoice {
  const _PhotoFlowChoice({
    required this.photoId,
    required this.photo,
    required this.commonName,
    this.species,
  });

  final String photoId;

  /// The photo itself, when it travelled along (as `extra`) from Foto.
  final Photo? photo;
  final String commonName;
  final Species? species;
}

/// Where a photo flow ends: saving a new plant ([_PhotoFlow.savePlantEnd])
/// or the Novo anúncio ([_ListingFlow.donateEnd]).
class _PhotoFlowEnd {
  const _PhotoFlowEnd({
    required this.saveLabel,
    required this.nameTitle,
    required this.save,
    this.needsPhoto = false,
  });

  /// The action of the Tela da espécie, such as "Salvar no meu jardim".
  final String saveLabel;

  /// The title of the dialog that asks the name where there is none yet
  /// (Foto não reconhecida, Limite diário).
  final String nameTitle;

  final void Function(BuildContext context, _PhotoFlowChoice choice) save;

  /// Whether [save] needs [_PhotoFlowChoice.photo], not only its id. Without
  /// it (a location opened by hand) the actions that save do not show.
  final bool needsPhoto;
}

/// A photo flow under [root]: Foto, then Candidatos, Busca and Tela da
/// espécie as its child routes, pushed over Foto, so going back finds the
/// same photo. They get the uploaded photo's id in the query and the
/// [Photo] itself as `extra`. Choosing a species, or "Salvar só com o nome",
/// ends in [end].
GoRoute _photoFlowRoute(
  _PhotoFlow flow, {
  required String root,
  required _PhotoFlowEnd end,
}) {
  Photo? photoOf(GoRouterState state) =>
      state.extra is Photo ? state.extra! as Photo : null;

  /// Saves the name (and the species) chosen with the photo, or null when
  /// [end] cannot with what the location has.
  void Function(String commonName, Species? species)? saver(
    BuildContext context,
    String? photoId,
    Photo? photo,
  ) {
    if (photoId == null || (end.needsPhoto && photo == null)) return null;
    return (commonName, species) => end.save(
      context,
      _PhotoFlowChoice(
        photoId: photoId,
        photo: photo,
        commonName: commonName,
        species: species,
      ),
    );
  }

  return GoRoute(
    path: root,
    builder: (context, state) => flow.photoScreen(
      context,
      state,
      onIdentify: (photo) => context.push<PhotoSource>(
        Routes.candidates(photo.id, root: root),
        extra: photo,
      ),
      onSearchByName: (photo) => context.push(
        Routes.searchByName(photoId: photo.id, root: root),
        extra: photo,
      ),
    ),
    routes: [
      GoRoute(
        path: '${Routes._candidatesPath}/:${Routes._photoIdParam}',
        builder: (context, state) {
          final photoId = Routes.candidatesPhotoIdOf(state);
          final photo = photoOf(state);
          final save = saver(context, photoId, photo);
          final search = Routes.searchByName(photoId: photoId, root: root);
          return flow.candidatesScreen(
            context,
            state,
            // The choice is made: Candidatos leaves the stack, and back from
            // the next screen is Foto.
            onSpecies: (species) => context.pushReplacement(
              Routes.species(species.id, photoId: photoId, root: root),
              extra: photo,
            ),
            onNoneOfThese: () => context.pushReplacement(search, extra: photo),
            onSearchByName: () => context.push(search, extra: photo),
            onSaveNameOnly: save == null
                ? null
                : () async {
                    final name = await showPlantNameDialog(
                      context,
                      title: end.nameTitle,
                    );
                    if (name != null && context.mounted) save(name, null);
                  },
          );
        },
      ),
      GoRoute(
        path: Routes._searchPath,
        builder: (context, state) {
          final photoId = Routes.photoIdOf(state);
          final photo = photoOf(state);
          final save = saver(context, photoId, photo);
          return flow.searchScreen(
            onSpecies: (species) => context.push(
              Routes.species(species.id, photoId: photoId, root: root),
              extra: photo,
            ),
            onSaveNameOnly: save == null ? null : (name) => save(name, null),
          );
        },
      ),
      GoRoute(
        path: '${Routes._speciesPath}/:${Routes._speciesIdParam}',
        builder: (context, state) {
          final save = saver(context, Routes.photoIdOf(state), photoOf(state));
          return ViewModelScope(
            create: () => SpeciesViewModel(
              catalogRepository: flow.catalogRepository,
              speciesId: Routes.speciesIdOf(state),
            )..load(),
            builder: (viewModel) => SpeciesScreen(
              viewModel: viewModel,
              openUrl: flow.openUrl,
              saveLabel: end.saveLabel,
              onSave: save == null
                  ? null
                  : (species) => save(species.commonName, species),
            ),
          );
        },
      ),
    ],
  );
}
