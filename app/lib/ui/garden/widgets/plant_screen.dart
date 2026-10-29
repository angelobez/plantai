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

/// Tela da planta, as in the Claude Design screen (`M-planta`): the User's
/// photo on top and a white panel over it with the plant's name, its species
/// (reference photo, names and credit) and the full care guide. A plant
/// saved with only a name shows just the photo and the name. While Claude
/// writes the guide, the loading state says "gerando dicas…".
///
/// Read only for now. The actions go in the panel: "Editar nome" next to the
/// name ([_PlantView]'s header row), "Definir espécie" where the species
/// card is for a plant without one, and "Remover do jardim" at the bottom.
class PlantScreen extends StatelessWidget {
  const PlantScreen({
    super.key,
    required this.viewModel,
    required this.openUrl,
  });

  final PlantViewModel viewModel;

  /// Opens the reference photo's credit link.
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final plant = viewModel.plant;
          final Widget body;
          if (plant != null) {
            body = _PlantView(plant: plant, openUrl: openUrl);
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
  const _PlantView({required this.plant, required this.openUrl});

  final Plant plant;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final species = plant.species;
    return PhotoPanelScroll(
      photo: PhotoImage(photo: plant.photo),
      photoHeight: 270,
      children: [
        Text(
          plant.commonName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        if (species != null) ...[
          const SizedBox(height: 14),
          _SpeciesCard(species: species, openUrl: openUrl),
          const SizedBox(height: 14),
          CareGuideView(careGuide: species.careGuide),
        ],
        const SizedBox(height: 28),
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
