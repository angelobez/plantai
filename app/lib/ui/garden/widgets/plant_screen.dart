import 'package:flutter/material.dart';

import '../../../data/services/api/models/plant.dart';
import '../../../data/services/api/models/species.dart';
import '../../auth/widgets/form_message.dart';
import '../../core/care_guide/care_guide_view.dart';
import '../../core/themes/colors.dart';
import '../../core/url_opener.dart';
import '../../core/widgets/photo_image.dart';
import '../../core/widgets/photo_panel_scroll.dart';
import '../../core/widgets/reference_photo_credit.dart';
import '../../core/widgets/round_back_button.dart';
import '../view_models/plant_view_model.dart';
import 'plant_name_dialog.dart';

/// Tela da planta, as in the Claude Design screen (`M-planta`): the User's
/// photo on top and a white panel over it with the plant's name, its species
/// (reference photo, names and credit) and the full care guide. A plant
/// saved with only a name shows just the photo and the name. While Claude
/// writes the guide, the loading state says "gerando dicas…".
///
/// The actions are in the panel: "Editar nome" as a round button next to
/// the name, and "Remover do jardim" at the bottom, after a confirmation.
/// A plant without a species shows "Definir espécie" where the species card
/// would be, with its two ways in: [onSearchSpecies] and
/// [onIdentifySpecies]. A failed rename or removal shows a [SnackBar] with
/// the message and, when it makes sense, "Tentar de novo".
class PlantScreen extends StatelessWidget {
  const PlantScreen({
    super.key,
    required this.viewModel,
    required this.openUrl,
    required this.onRemoved,
    this.onSearchSpecies,
    this.onIdentifySpecies,
  });

  final PlantViewModel viewModel;

  /// Opens the reference photo's credit link.
  final UrlOpener openUrl;

  /// The plant left the garden: the screen goes back to the Jardim.
  final VoidCallback onRemoved;

  Future<void> _editName(BuildContext context, Plant plant) async {
    final name = await showPlantNameDialog(
      context,
      initialName: plant.commonName,
      title: 'Editar nome',
    );
    if (name == null || !context.mounted) return;
    await _rename(context, name);
  }

  Future<void> _rename(BuildContext context, String name) async {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    if (await viewModel.rename(name) || !context.mounted) return;
    _showActionError(context, retry: () => _rename(context, name));
  }

  Future<void> _confirmRemove(BuildContext context, Plant plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _RemoveDialog(plantName: plant.commonName),
    );
    if (confirmed != true || !context.mounted) return;
    await _remove(context);
  }

  Future<void> _remove(BuildContext context) async {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    if (await viewModel.remove()) {
      onRemoved();
      return;
    }
    if (context.mounted) {
      _showActionError(context, retry: () => _remove(context));
    }
  }

  void _showActionError(BuildContext context, {required VoidCallback retry}) {
    final error = viewModel.actionError;
    if (error == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(error),
        action: viewModel.canRetryAction
            ? SnackBarAction(
                label: 'Tentar de novo',
                onPressed: () {
                  if (context.mounted) retry();
                },
              )
            : null,
      ),
    );
  }

  /// "Definir espécie" by the Busca: completes with the id of the chosen
  /// species, or null when the User leaves without one. Without it (and
  /// [onIdentifySpecies]), "Definir espécie" does not show.
  final Future<String?> Function()? onSearchSpecies;

  /// "Definir espécie" by a new photo, which identifies the species but
  /// never becomes the plant's photo: completes as [onSearchSpecies].
  final Future<String?> Function()? onIdentifySpecies;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final plant = viewModel.plant;
          final Widget body;
          if (plant != null) {
            body = _PlantView(
              plant: plant,
              openUrl: openUrl,
              isSaving: viewModel.isSaving,
              onEditName: () => _editName(context, plant),
              onRemove: () => _confirmRemove(context, plant),
              defineSpecies:
                  onSearchSpecies == null && onIdentifySpecies == null
                  ? null
                  : _DefineSpecies(
                      viewModel: viewModel,
                      onSearch: onSearchSpecies,
                      onIdentify: onIdentifySpecies,
                    ),
            );
          } else if (viewModel.loadError case final error?
              when !viewModel.isLoading) {
            body = Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: FormMessage(
                  error: error,
                  onRetry: viewModel.canRetry ? viewModel.load : null,
                ),
              ),
            );
          } else {
            body = CareGuideLoading(
              generating: viewModel.isGeneratingCareGuide,
            );
          }
          return TopLeftOverlay(body: body, overlay: const RoundBackButton());
        },
      ),
    );
  }
}

class _PlantView extends StatelessWidget {
  const _PlantView({
    required this.plant,
    required this.openUrl,
    required this.isSaving,
    required this.onEditName,
    required this.onRemove,
    required this.defineSpecies,
  });

  final Plant plant;
  final UrlOpener openUrl;

  /// While an action runs, the others wait.
  final bool isSaving;
  final VoidCallback onEditName;
  final VoidCallback onRemove;

  /// Shown instead of the species card while the plant has none.
  final Widget? defineSpecies;

  @override
  Widget build(BuildContext context) {
    final species = plant.species;
    return PhotoPanelScroll(
      photo: PhotoImage(photo: plant.photo),
      photoHeight: 270,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                plant.commonName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: isSaving ? null : onEditName,
              tooltip: 'Editar nome',
              icon: const Icon(Icons.edit_outlined, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.mist,
                foregroundColor: AppColors.forest,
                fixedSize: const Size.square(40),
              ),
            ),
          ],
        ),
        if (species != null) ...[
          const SizedBox(height: 14),
          _SpeciesCard(species: species, openUrl: openUrl),
          const SizedBox(height: 14),
          CareGuideView(careGuide: species.careGuide),
        ] else if (defineSpecies case final defineSpecies?) ...[
          const SizedBox(height: 14),
          defineSpecies,
        ],
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: isSaving ? null : onRemove,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Remover do jardim'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// The plant's species: the reference photo, the common and scientific
/// names, and the photo's credit.
class _SpeciesCard extends StatelessWidget {
  const _SpeciesCard({required this.species, required this.openUrl});

  final Species species;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: 52,
                    child: ColoredBox(
                      color: const Color(0xFFC9DECD),
                      child: ReferencePhotoImage(photo: species.referencePhoto),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        species.commonName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        species.scientificName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ReferencePhotoCredit(
              photo: species.referencePhoto,
              openUrl: openUrl,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Remover do jardim?": the plant and its photo go for good.
class _RemoveDialog extends StatelessWidget {
  const _RemoveDialog({required this.plantName});

  final String plantName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Remover do jardim?'),
      content: Text('“$plantName” e a foto dela saem do seu jardim de vez.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          // The theme's pill is as wide as the screen; not in a dialog.
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            minimumSize: const Size(96, 44),
          ),
          child: const Text('Remover'),
        ),
      ],
    );
  }
}

/// "Definir espécie", on a plant saved with only a name: the Busca or a new
/// identification gives the species, which the ViewModel sets.
class _DefineSpecies extends StatelessWidget {
  const _DefineSpecies({
    required this.viewModel,
    required this.onSearch,
    required this.onIdentify,
  });

  final PlantViewModel viewModel;
  final Future<String?> Function()? onSearch;
  final Future<String?> Function()? onIdentify;

  /// Runs [choose] and sets the species it gives, if any.
  VoidCallback? _choosing(Future<String?> Function()? choose) {
    if (choose == null || viewModel.isDefiningSpecies) return null;
    return () async {
      final speciesId = await choose();
      if (speciesId != null) await viewModel.defineSpecies(speciesId);
    };
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 46),
      foregroundColor: AppColors.forest,
      side: const BorderSide(color: AppColors.forest, width: 1.5),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Definir espécie',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Escolha a espécie para receber as dicas de cuidado. Depois de '
            'definida, a espécie não muda: se estiver errada, remova a planta '
            'e adicione de novo.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _choosing(onSearch),
            style: buttonStyle,
            icon: const Icon(Icons.search, size: 20),
            label: const Text('Buscar pelo nome'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _choosing(onIdentify),
            style: buttonStyle,
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            label: const Text('Identificar pela foto'),
          ),
          if (viewModel.isDefiningSpecies) ...[
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Definindo a espécie…',
                  style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                ),
              ],
            ),
          ],
          if (viewModel.speciesError case final error?) ...[
            const SizedBox(height: 12),
            FormMessage(
              error: error,
              onRetry: viewModel.canRetrySpecies
                  ? viewModel.retryDefineSpecies
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
