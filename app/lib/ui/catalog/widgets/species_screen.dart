import 'package:flutter/material.dart';

import '../../../data/services/api/models/species.dart';
import '../../auth/widgets/form_message.dart';
import '../../core/themes/colors.dart';
import '../../core/url_opener.dart';
import '../../core/widgets/photo_image.dart';
import '../../core/widgets/reference_photo_credit.dart';
import '../view_models/species_view_model.dart';

/// Tela da espécie, as in the Claude Design screen (`M-especie`): the
/// reference photo on top and a white panel over it with the common name,
/// "científico · também chamada de …" and the photo's credit.
///
/// The care rows and texts ("Dicas de cuidado pelo Claude") go in the panel,
/// between the names and the credit; "Salvar no meu jardim" goes at the
/// bottom, in [Scaffold.bottomNavigationBar].
class SpeciesScreen extends StatelessWidget {
  const SpeciesScreen({
    super.key,
    required this.viewModel,
    required this.openUrl,
  });

  final SpeciesViewModel viewModel;

  /// Opens the credit's link.
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final species = viewModel.species;
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
            body = const Center(child: CircularProgressIndicator());
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              body,
              const Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: _BackButton(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

const _photoHeight = 290.0;
const _panelOverlap = 26.0;

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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _photoHeight,
            child: ColoredBox(
              color: const Color(0xFF7FA886),
              child: ReferencePhotoImage(photo: species.referencePhoto),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -_panelOverlap),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_panelOverlap),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ReferencePhotoCredit(
                      photo: species.referencePhoto,
                      openUrl: openUrl,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

/// The white circle over the photo.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Voltar',
      onPressed: () => Navigator.of(context).maybePop(),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        foregroundColor: AppColors.ink,
        fixedSize: const Size.square(44),
      ),
      icon: const Icon(Icons.chevron_left, size: 24),
    );
  }
}
