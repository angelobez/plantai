import 'package:flutter/material.dart';

import '../../../data/services/api/models/identification.dart';
import '../../../data/services/api/models/photo.dart';
import '../../../data/services/api/models/reference_photo.dart';
import '../../../data/services/api/models/species_summary.dart';
import '../../auth/widgets/form_message.dart';
import '../../core/themes/colors.dart';
import '../../core/url_opener.dart';
import '../../core/widgets/photo_image.dart';
import '../view_models/candidates_view_model.dart';
import 'daily_limit_view.dart';
import 'not_recognized_view.dart';

/// The screens after "Identificar pela foto", following
/// [CandidatesViewModel.stage]: "Identificando a planta…", then Candidatos
/// (`M-candidatos`), Foto não reconhecida or Limite diário. A failure shows
/// its message with "Tentar de novo" and the search.
class CandidatesScreen extends StatelessWidget {
  const CandidatesScreen({
    super.key,
    required this.viewModel,
    required this.photo,
    required this.openUrl,
    required this.onSpecies,
    required this.onNoneOfThese,
    required this.onTakeAnother,
    required this.onSearchByName,
    this.onSaveNameOnly,
  });

  final CandidatesViewModel viewModel;

  /// The User's photo, to compare with the candidates; null when the route
  /// did not get it (the screens then do without).
  final Photo? photo;
  final UrlOpener openUrl;

  /// A candidate was chosen: its species, now in the Catalog.
  final ValueChanged<SpeciesSummary> onSpecies;

  /// "Nenhuma destas", once recorded.
  final VoidCallback onNoneOfThese;

  /// "Tirar outra foto" (Foto não reconhecida).
  final VoidCallback onTakeAnother;

  /// "Buscar pelo nome".
  final VoidCallback onSearchByName;

  /// "Salvar só com o nome"; the button does not show while this is null
  /// ("Definir espécie", where the plant has its name already).
  final VoidCallback? onSaveNameOnly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => switch (viewModel.stage) {
          IdentificationStage.identifying => const _Framed(
            child: _Identifying(),
          ),
          IdentificationStage.failed => _Framed(
            child: _Failed(
              viewModel: viewModel,
              onSearchByName: onSearchByName,
            ),
          ),
          IdentificationStage.candidates => _Framed(
            child: _Candidates(
              viewModel: viewModel,
              photo: photo,
              openUrl: openUrl,
              onSpecies: onSpecies,
              onNoneOfThese: onNoneOfThese,
            ),
          ),
          IdentificationStage.notRecognized => NotRecognizedView(
            photo: photo,
            onTakeAnother: onTakeAnother,
            onSearchByName: onSearchByName,
            onSaveNameOnly: onSaveNameOnly,
          ),
          IdentificationStage.dailyLimit => DailyLimitView(
            photo: photo,
            onSearchByName: onSearchByName,
            onSaveNameOnly: onSaveNameOnly,
          ),
        },
      ),
    );
  }
}

/// The header of Candidatos ("Voltar" and the question) over [child].
class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Voltar',
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mist,
                        foregroundColor: AppColors.ink,
                        fixedSize: const Size(44, 44),
                      ),
                      icon: const Icon(Icons.chevron_left, size: 24),
                    ),
                    const Expanded(
                      child: Text(
                        'Qual destas é a sua?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Identifying extends StatelessWidget {
  const _Identifying();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Identificando a planta…',
              style: TextStyle(fontSize: 15, color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.viewModel, required this.onSearchByName});

  final CandidatesViewModel viewModel;
  final VoidCallback onSearchByName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FormMessage(
          error: viewModel.error,
          onRetry: viewModel.canRetry ? viewModel.identify : null,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onSearchByName,
          child: const Text('Buscar pelo nome'),
        ),
      ],
    );
  }
}

class _Candidates extends StatelessWidget {
  const _Candidates({
    required this.viewModel,
    required this.photo,
    required this.openUrl,
    required this.onSpecies,
    required this.onNoneOfThese,
  });

  final CandidatesViewModel viewModel;
  final Photo? photo;
  final UrlOpener openUrl;
  final ValueChanged<SpeciesSummary> onSpecies;
  final VoidCallback onNoneOfThese;

  Future<void> _choose(int index) async {
    final species = await viewModel.choose(index);
    if (species != null) onSpecies(species);
  }

  Future<void> _chooseNone() async {
    if (await viewModel.chooseNone()) onNoneOfThese();
  }

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    final candidates = viewModel.candidates;
    final remainingToday = viewModel.remainingToday;
    final choosing = viewModel.isChoosing;
    final choiceError = viewModel.choiceError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            children: [
              Row(
                children: [
                  if (photo != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox.square(
                        dimension: 52,
                        child: PhotoImage(photo: photo),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Expanded(
                    child: Text(
                      'Compare a sua foto com as fotos de cada sugestão e '
                      'escolha a que for igual.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
              if (choiceError != null) ...[
                const SizedBox(height: 12),
                FormMessage(error: choiceError),
              ],
              for (final (index, candidate) in candidates.indexed)
                _CandidateTile(
                  candidate: candidate,
                  openUrl: openUrl,
                  onChoose: choosing ? null : () => _choose(index),
                ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: choosing ? null : _chooseNone,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Nenhuma destas'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Identificação: Pl@ntNet · fotos de referência dos autores '
                  'no Pl@ntNet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
                if (remainingToday != null)
                  Text(
                    'Restam $remainingToday de 10 identificações hoje',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One candidate: up to 3 Pl@ntNet photos (each opens its page), their
/// authors, the name, the scientific name and "É esta".
class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.openUrl,
    required this.onChoose,
  });

  final Candidate candidate;
  final UrlOpener openUrl;
  final VoidCallback? onChoose;

  static const _maxImages = 3;

  @override
  Widget build(BuildContext context) {
    final images = candidate.images.take(_maxImages).toList();
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (images.isNotEmpty) ...[
              Row(
                children: [
                  for (var i = 0; i < _maxImages; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: i < images.length
                          ? _CandidateImage(photo: images[i], openUrl: openUrl)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Fotos: ${images.map((image) => '${image.author} · ${image.license}').join(', ')}',
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (candidate.commonName != null)
                        Text(
                          candidate.scientificName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: AppColors.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: onChoose,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mist,
                    foregroundColor: AppColors.forest,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('É esta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateImage extends StatelessWidget {
  const _CandidateImage({required this.photo, required this.openUrl});

  final ReferencePhoto photo;
  final UrlOpener openUrl;

  @override
  Widget build(BuildContext context) {
    final source = Uri.tryParse(photo.sourceUrl);
    return Semantics(
      link: source != null,
      label: 'Foto de ${photo.author}',
      child: GestureDetector(
        onTap: source == null ? null : () => openUrl(source),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(height: 86, child: ReferencePhotoImage(photo: photo)),
        ),
      ),
    );
  }
}
