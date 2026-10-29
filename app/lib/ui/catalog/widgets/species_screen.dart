import 'package:flutter/material.dart';

import '../../../data/services/api/models/species.dart';
import '../../auth/widgets/form_message.dart';
import '../../core/care_guide/care_guide_view.dart';
import '../../core/themes/colors.dart';
import '../../core/url_opener.dart';
import '../../core/widgets/photo_image.dart';
import '../../core/widgets/photo_panel_scroll.dart';
import '../../core/widgets/reference_photo_credit.dart';
import '../../core/widgets/round_back_button.dart';
import '../view_models/species_view_model.dart';

/// Tela da espécie, as in the Claude Design screen (`M-especie`): the
/// reference photo on top and a white panel over it with the common name,
/// "científico · também chamada de …", the care guide ([CareGuideView]) and
/// the photo's credit. While Claude writes the guide, the loading state says
/// "gerando dicas…".
///
/// With [onSaveToGarden] (a photo in the flow), "Salvar no meu jardim" sits
/// at the bottom once the species is read.
class SpeciesScreen extends StatelessWidget {
  const SpeciesScreen({
    super.key,
    required this.viewModel,
    required this.openUrl,
    this.onSaveToGarden,
  });

  final SpeciesViewModel viewModel;

  /// Opens the credit's link.
  final UrlOpener openUrl;

  /// Saves the species shown as a plant, with the flow's photo.
  final ValueChanged<Species>? onSaveToGarden;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final species = viewModel.species;
        final onSave = onSaveToGarden;
        final Widget body;
        if (species != null) {
          body = _SpeciesView(species: species, openUrl: openUrl);
        } else if (viewModel.loadError case final error?
            when !viewModel.isLoading) {
          body = _LoadError(
            message: error,
            onRetry: viewModel.canRetry ? viewModel.load : null,
          );
        } else {
          body = CareGuideLoading(generating: viewModel.isGeneratingCareGuide);
        }
        return Scaffold(
          body: TopLeftOverlay(body: body, overlay: const RoundBackButton()),
          bottomNavigationBar: species == null || onSave == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: FilledButton(
                      onPressed: () => onSave(species),
                      child: const Text('Salvar no meu jardim'),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _SpeciesView extends StatelessWidget {
  const _SpeciesView({required this.species, required this.openUrl});

  final Species species;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final otherNames = species.otherNames;
    final subtitle = [
      species.scientificName,
      if (otherNames.isNotEmpty) 'também chamada de ${otherNames.join(', ')}',
    ].join(' · ');
    return PhotoPanelScroll(
      photo: ReferencePhotoImage(photo: species.referencePhoto),
      photoHeight: 290,
      children: [
        Text(
          species.commonName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 14),
        CareGuideView(careGuide: species.careGuide),
        const SizedBox(height: 14),
        ReferencePhotoCredit(photo: species.referencePhoto, openUrl: openUrl),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: FormMessage(error: message, onRetry: onRetry),
      ),
    );
  }
}
