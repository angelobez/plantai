part of 'router.dart';

/// The photo flow that saves a new plant: Foto, then Candidatos, Busca and
/// Tela da espécie as its child routes, pushed over Foto, so going back
/// finds the same photo. They get the uploaded photo's id in the query.
GoRoute _identifyRoute(_PhotoFlow flow) => GoRoute(
  path: Routes.identify,
  builder: (context, state) => flow.photoScreen(
    context,
    state,
    onIdentify: (photo) =>
        context.push<PhotoSource>(Routes.candidates(photo.id), extra: photo),
    onSearchByName: (photo) =>
        context.push(Routes.searchByName(photoId: photo.id)),
  ),
  routes: [
    GoRoute(
      path: '${Routes._candidatesPath}/:${Routes._photoIdParam}',
      builder: (context, state) {
        final photoId = Routes.candidatesPhotoIdOf(state);
        return flow.candidatesScreen(
          context,
          state,
          // The choice is made: Candidatos leaves the stack, and back from the
          // next screen is Foto.
          onSpecies: (species) => context.pushReplacement(
            Routes.species(species.id, photoId: photoId),
          ),
          onNoneOfThese: () =>
              context.pushReplacement(Routes.searchByName(photoId: photoId)),
          onSearchByName: () =>
              context.push(Routes.searchByName(photoId: photoId)),
          onSaveNameOnly: () => flow.askNameAndSave(context, photoId),
        );
      },
    ),
    GoRoute(
      path: Routes._searchPath,
      builder: (context, state) {
        final photoId = Routes.photoIdOf(state);
        return flow.searchScreen(
          onSpecies: (species) =>
              context.push(Routes.species(species.id, photoId: photoId)),
          onSaveNameOnly: photoId == null
              ? null
              : (name) => flow.saveAndOpen(
                  context,
                  NewPlant(photoId: photoId, commonName: name),
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
            catalogRepository: flow.catalogRepository,
            speciesId: Routes.speciesIdOf(state),
          )..load(),
          builder: (viewModel) => SpeciesScreen(
            viewModel: viewModel,
            openUrl: flow.openUrl,
            onSaveToGarden: photoId == null
                ? null
                : (species) => flow.saveAndOpen(
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
);
