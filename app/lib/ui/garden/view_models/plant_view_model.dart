import 'package:flutter/foundation.dart';

import '../../../data/repositories/garden/garden_repository.dart';
import '../../../data/services/api/models/plant.dart';
import '../../../domain/models/care_guide_generating.dart';
import '../../../domain/models/garden_failure.dart';
import '../../core/care_guide/wait_for_care_guide.dart';
import '../garden_failure_message.dart';

/// Tela da planta: reads one of the User's plants, with its species and care
/// guide.
///
/// While Claude writes the guide (a slow first answer, or `202
/// CARE_GUIDE_GENERATING`), [isGeneratingCareGuide] is true and the read is
/// tried again after each `Retry-After`; after 60 s it gives up with
/// "Dicas indisponíveis no momento." ([waitForCareGuide]).
///
/// The actions on the plant ([rename], [remove]; setting the species goes
/// next to them) answer whether they worked. While one runs, [isSaving] is
/// true; when one fails, [actionError] says why and [canRetryAction] whether
/// trying again makes sense. The repository tells the Jardim list itself.
class PlantViewModel extends ChangeNotifier {
  PlantViewModel({required this._gardenRepository, required this.plantId});

  final GardenRepository _gardenRepository;
  final String plantId;

  Plant? _plant;
  Plant? get plant => _plant;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Whether the screen says "gerando dicas…" while [isLoading].
  bool _isGeneratingCareGuide = false;
  bool get isGeneratingCareGuide => _isGeneratingCareGuide;

  /// Why the plant could not be read.
  String? _loadError;
  String? get loadError => _loadError;

  /// Whether loading again makes sense for [loadError].
  bool _canRetry = false;
  bool get canRetry => _canRetry;

  /// Whether [rename] or [remove] is waiting for the API.
  bool _isSaving = false;
  bool get isSaving => _isSaving;

  /// Why the last [rename] or [remove] failed.
  String? _actionError;
  String? get actionError => _actionError;

  /// Whether trying [actionError]'s action again makes sense.
  bool _canRetryAction = false;
  bool get canRetryAction => _canRetryAction;

  bool _disposed = false;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    _canRetry = false;
    _notify();
    try {
      _plant = await waitForCareGuide(
        () => _gardenRepository.plant(plantId),
        onGenerating: () {
          _isGeneratingCareGuide = true;
          _notify();
        },
        isCancelled: () => _disposed,
      );
    } on GardenFailure catch (failure) {
      _loadError = gardenFailureMessage(failure);
      _canRetry = failure != GardenFailure.notFound;
    } on CareGuideGenerating {
      _loadError = careGuideUnavailableMessage;
      _canRetry = true;
    } finally {
      _isLoading = false;
      _isGeneratingCareGuide = false;
      _notify();
    }
  }

  /// Gives the plant the [name] the User typed (already trimmed and
  /// checked by the dialog). Answers whether it worked.
  Future<bool> rename(String name) => _act(() async {
    final renamed = await _gardenRepository.update(plantId, commonName: name);
    if (_plant case final plant?) {
      _plant = Plant(
        id: plant.id,
        commonName: renamed.commonName,
        photo: plant.photo,
        species: plant.species,
      );
    }
  });

  /// Removes the plant and its photo from the garden. Answers whether it
  /// worked; the screen then leaves.
  Future<bool> remove() => _act(() => _gardenRepository.remove(plantId));

  Future<bool> _act(Future<void> Function() action) async {
    _isSaving = true;
    _actionError = null;
    _canRetryAction = false;
    _notify();
    try {
      await action();
      return true;
    } on GardenFailure catch (failure) {
      _actionError = gardenFailureMessage(failure);
      _canRetryAction = failure != GardenFailure.notFound;
      return false;
    } finally {
      _isSaving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
