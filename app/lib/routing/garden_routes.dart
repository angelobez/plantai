part of 'router.dart';

/// The Jardim tab: the list, the Tela da planta over the whole shell
/// ([rootNavigatorKey]), and its "Definir espécie" screens.
GoRoute _gardenRoute(
  _PhotoFlow flow,
  _ListingFlow listingFlow, {
  required GlobalKey<NavigatorState> rootNavigatorKey,
}) => GoRoute(
  path: Routes.garden,
  builder: (context, state) => ViewModelScope(
    create: () =>
        GardenViewModel(gardenRepository: flow.gardenRepository)..load(),
    builder: (viewModel) => GardenScreen(
      viewModel: viewModel,
      onPlant: (plant) => context.push(Routes.plant(plant.id)),
      onIdentify: () => flow.open(context),
    ),
  ),
  routes: [
    // Over the whole shell: the Tela da planta has no bottom bar, and back is
    // the list.
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '${Routes._plantPath}/:${Routes._plantIdParam}',
      builder: (context, state) => ViewModelScope(
        create: () => PlantViewModel(
          gardenRepository: flow.gardenRepository,
          plantId: Routes.plantIdOf(state),
        )..load(),
        builder: (viewModel) {
          final plantId = Routes.plantIdOf(state);
          return PlantScreen(
            viewModel: viewModel,
            openUrl: flow.openUrl,
            onDonate: (plant) =>
                listingFlow.donate(context, ListingDraft.fromPlant(plant)),
            // The list already left out the plant (the repository told it).
            onRemoved: () => context.go(Routes.garden),
            onSearchSpecies: () =>
                context.push<String>(Routes.defineSpeciesSearch(plantId)),
            onIdentifySpecies: () async {
              final source = await showPhotoSourceSheet(context);
              if (source == null || !context.mounted) {
                return null;
              }
              return context.push<String>(
                Routes.defineSpeciesPhoto(plantId, source),
              );
            },
          );
        },
      ),
      // "Definir espécie": each screen closes with the id of the chosen
      // species, back to the Tela da planta, which sets it. Nothing here saves
      // a plant or a photo.
      routes: [
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '${Routes._defineSpeciesPath}/${Routes._searchPath}',
          builder: (context, state) => flow.searchScreen(
            onSpecies: (species) => context.pop(species.id),
          ),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '${Routes._defineSpeciesPath}/${Routes._photoPath}',
          builder: (context, state) {
            final plantId = Routes.plantIdOf(state);
            return flow.photoScreen(
              context,
              state,
              onIdentify: (photo) async {
                final result = await context.push<Object>(
                  Routes.defineSpeciesCandidates(plantId, photo.id),
                  extra: photo,
                );
                if (result is String && context.mounted) {
                  context.pop(result);
                }
                return result is PhotoSource ? result : null;
              },
              onSearchByName: (_) => flow.passSpeciesBack(
                context,
                Routes.defineSpeciesSearch(plantId),
              ),
            );
          },
          routes: [
            GoRoute(
              parentNavigatorKey: rootNavigatorKey,
              path: '${Routes._candidatesPath}/:${Routes._photoIdParam}',
              builder: (context, state) {
                final search = Routes.defineSpeciesSearch(
                  Routes.plantIdOf(state),
                );
                return flow.candidatesScreen(
                  context,
                  state,
                  // The choice already ran: the species is in the Catalog.
                  onSpecies: (species) => context.pop(species.id),
                  // The choice is made: back from Busca is Foto.
                  onNoneOfThese: () async {
                    final speciesId = await context.push<String>(search);
                    if (context.mounted) context.pop(speciesId);
                  },
                  onSearchByName: () => flow.passSpeciesBack(context, search),
                );
              },
            ),
          ],
        ),
      ],
    ),
  ],
);
