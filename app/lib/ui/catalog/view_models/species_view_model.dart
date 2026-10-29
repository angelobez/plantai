import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalog/catalog_repository.dart';
import '../../../data/services/api/models/species.dart';
import '../../../domain/models/catalog_failure.dart';

/// Tela da espécie: reads one species of the Catalog.
///
/// The care guide (and its "gerando dicas…" state) is not here yet; it
/// comes with `careGuide` in the same response.
class SpeciesViewModel extends ChangeNotifier {
  SpeciesViewModel({required this._catalogRepository, required this.speciesId});

  final CatalogRepository _catalogRepository;
  final String speciesId;

  Species? _species;
  Species? get species => _species;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Why the species could not be read.
  String? _loadError;
  String? get loadError => _loadError;

  /// Whether loading again makes sense for [loadError].
  bool _canRetry = false;
  bool get canRetry => _canRetry;

  bool _disposed = false;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    _canRetry = false;
    _notify();
    try {
      _species = await _catalogRepository.species(speciesId);
    } on CatalogFailure catch (failure) {
      _loadError = _message(failure);
      _canRetry = failure != CatalogFailure.notFound;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  static String _message(CatalogFailure failure) => switch (failure) {
    CatalogFailure.noConnection =>
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    CatalogFailure.notFound => 'Não achei essa espécie no Catálogo.',
    CatalogFailure.unknown => 'Algo deu errado. Tente de novo.',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
