import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalog/catalog_repository.dart';
import '../../../data/services/api/models/species.dart';
import '../../../domain/models/care_guide_generating.dart';
import '../../../domain/models/catalog_failure.dart';
import '../../core/care_guide/wait_for_care_guide.dart';
import '../../core/view_models/safe_notify.dart';

/// Tela da espécie: reads one species of the Catalog, with its care guide.
///
/// While Claude writes the guide (a slow first answer, or `202
/// CARE_GUIDE_GENERATING`), [isGeneratingCareGuide] is true and the read is
/// tried again after each `Retry-After`; after 60 s it gives up with
/// "Dicas indisponíveis no momento." ([waitForCareGuide]).
class SpeciesViewModel extends ChangeNotifier with SafeNotify {
  SpeciesViewModel({required this._catalogRepository, required this.speciesId});

  final CatalogRepository _catalogRepository;
  final String speciesId;

  Species? _species;
  Species? get species => _species;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Whether the screen says "gerando dicas…" while [isLoading].
  bool _isGeneratingCareGuide = false;
  bool get isGeneratingCareGuide => _isGeneratingCareGuide;

  /// Why the species could not be read.
  String? _loadError;
  String? get loadError => _loadError;

  /// Whether loading again makes sense for [loadError].
  bool _canRetry = false;
  bool get canRetry => _canRetry;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    _canRetry = false;
    notify();
    try {
      _species = await waitForCareGuide(
        () => _catalogRepository.species(speciesId),
        onGenerating: () {
          _isGeneratingCareGuide = true;
          notify();
        },
        isCancelled: () => isDisposed,
      );
    } on CatalogFailure catch (failure) {
      _loadError = _message(failure);
      _canRetry = failure != CatalogFailure.notFound;
    } on CareGuideGenerating {
      _loadError = careGuideUnavailableMessage;
      _canRetry = true;
    } finally {
      _isLoading = false;
      _isGeneratingCareGuide = false;
      notify();
    }
  }

  static String _message(CatalogFailure failure) => switch (failure) {
    CatalogFailure.noConnection =>
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    CatalogFailure.notFound => 'Não achei essa espécie no Catálogo.',
    CatalogFailure.unknown => 'Algo deu errado. Tente de novo.',
  };
}
