import 'package:flutter/foundation.dart';

import '../../../data/repositories/identification/identification_repository.dart';
import '../../../data/services/api/models/identification.dart';
import '../../../data/services/api/models/species_summary.dart';
import '../../../domain/models/identification_failure.dart';
import '../../core/view_models/safe_notify.dart';

/// Which screen the identification leads to.
enum IdentificationStage {
  /// Waiting for Pl@ntNet (~2 s).
  identifying,

  /// Candidatos: up to 3 to choose from.
  candidates,

  /// Foto não reconhecida.
  notRecognized,

  /// Limite diário: today's 10 are used; the search still works.
  dailyLimit,

  /// The identification failed; [CandidatesViewModel.error] says why.
  failed,
}

/// Identifies the photo already sent ([photoId]) and holds the choice among
/// the candidates. The screen follows [stage].
class CandidatesViewModel extends ChangeNotifier with SafeNotify {
  CandidatesViewModel({
    required this._identificationRepository,
    required this.photoId,
  });

  final IdentificationRepository _identificationRepository;

  /// The photo being identified, as the API stored it.
  final String photoId;

  IdentificationStage _stage = IdentificationStage.identifying;
  IdentificationStage get stage => _stage;

  Identification? _identification;

  /// Best first; empty until there are candidates.
  List<Candidate> get candidates => _identification?.candidates ?? const [];

  /// Identifications the User still has today, once Pl@ntNet answered.
  int? get remainingToday => _identification?.remainingToday;

  /// Why the identification failed, at [IdentificationStage.failed].
  String? _error;
  String? get error => _error;

  /// Whether identifying again may work ("Tentar de novo").
  bool _canRetry = false;
  bool get canRetry => _canRetry;

  bool _isChoosing = false;
  bool get isChoosing => _isChoosing;

  /// Why the last choice failed; the candidates stay.
  String? _choiceError;
  String? get choiceError => _choiceError;

  /// Asks Pl@ntNet about the photo; also "Tentar de novo".
  Future<void> identify() async {
    _stage = IdentificationStage.identifying;
    _error = null;
    _canRetry = false;
    notify();
    try {
      final identification = await _identificationRepository.identify(photoId);
      _identification = identification;
      _stage = switch (identification.result) {
        IdentificationResult.recognized => IdentificationStage.candidates,
        IdentificationResult.notRecognized => IdentificationStage.notRecognized,
      };
    } on IdentificationFailure catch (failure) {
      if (failure == IdentificationFailure.dailyLimit) {
        _stage = IdentificationStage.dailyLimit;
      } else {
        _stage = IdentificationStage.failed;
        _error = _message(failure);
        _canRetry = failure != IdentificationFailure.notFound;
      }
    } finally {
      notify();
    }
  }

  /// "É esta" on the candidate at [index]: its species, now in the Catalog;
  /// null when it failed ([choiceError]) or another choice is on its way.
  Future<SpeciesSummary?> choose(int index) async {
    final identification = _identification;
    if (identification == null || _isChoosing) return null;
    return _choosing(
      () => _identificationRepository.choose(identification.id, index),
    );
  }

  /// "Nenhuma destas": whether the screen goes on to the search. It also
  /// goes on when this identification already had a choice, since the User
  /// only wants to search.
  Future<bool> chooseNone() async {
    final identification = _identification;
    if (identification == null || _isChoosing) return false;
    final recorded = await _choosing(() async {
      try {
        await _identificationRepository.chooseNone(identification.id);
      } on IdentificationFailure catch (failure) {
        if (failure != IdentificationFailure.alreadyChosen) rethrow;
      }
      return true;
    });
    return recorded ?? false;
  }

  Future<T?> _choosing<T>(Future<T> Function() call) async {
    _isChoosing = true;
    _choiceError = null;
    notify();
    try {
      return await call();
    } on IdentificationFailure catch (failure) {
      _choiceError = _message(failure);
      return null;
    } finally {
      _isChoosing = false;
      notify();
    }
  }

  static String _message(IdentificationFailure failure) => switch (failure) {
    IdentificationFailure.noConnection =>
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    IdentificationFailure.serviceUnavailable =>
      'O Pl@ntNet, que identifica as plantas, não respondeu. Tente de novo em '
          'instantes; esta tentativa não contou.',
    IdentificationFailure.notFound =>
      'Essa foto não está mais disponível. Tire outra foto.',
    IdentificationFailure.alreadyChosen =>
      'Você já escolheu uma opção para esta foto. Identifique de novo para '
          'escolher outra.',
    IdentificationFailure.dailyLimit =>
      'Você usou suas 10 identificações de hoje; amanhã tem mais.',
    IdentificationFailure.unknown => 'Algo deu errado. Tente de novo.',
  };
}
