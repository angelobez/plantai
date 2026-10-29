import 'dart:async';

import 'package:plantai/data/repositories/identification/identification_repository.dart';
import 'package:plantai/data/services/api/models/identification.dart';
import 'package:plantai/data/services/api/models/reference_photo.dart';
import 'package:plantai/data/services/api/models/species_summary.dart';
import 'package:plantai/domain/models/identification_failure.dart';

const jiboiaImage = ReferencePhoto(
  url: 'https://bs.plantnet.org/image/m/jiboia-1',
  author: 'Ana Ribeiro',
  license: 'CC BY-SA',
  sourceUrl: 'https://bs.plantnet.org/image/o/jiboia-1',
);

const jiboiaCandidate = Candidate(
  scientificName: 'Epipremnum aureum',
  commonName: 'Jiboia',
  score: 0.81,
  images: [
    jiboiaImage,
    ReferencePhoto(
      url: 'https://bs.plantnet.org/image/m/jiboia-2',
      author: 'Carlos Lima',
      license: 'CC BY',
      sourceUrl: 'https://bs.plantnet.org/image/o/jiboia-2',
    ),
  ],
);

/// A candidate whose Pl@ntNet names did not look like names.
const pinnatumCandidate = Candidate(
  scientificName: 'Epipremnum pinnatum',
  commonName: null,
  score: 0.13,
  images: [
    ReferencePhoto(
      url: 'https://bs.plantnet.org/image/m/pinnatum-1',
      author: 'Pedro Alves',
      license: 'CC BY-SA',
      sourceUrl: 'https://bs.plantnet.org/image/o/pinnatum-1',
    ),
  ],
);

const recognized = Identification(
  id: '0190e0d4-0000-7000-8000-0000000000d1',
  result: IdentificationResult.recognized,
  candidates: [jiboiaCandidate, pinnatumCandidate],
  remainingToday: 7,
);

const notRecognized = Identification(
  id: '0190e0d4-0000-7000-8000-0000000000d2',
  result: IdentificationResult.notRecognized,
  candidates: [],
  remainingToday: 6,
);

/// The species choosing [jiboiaCandidate] answers.
const jiboiaSpecies = SpeciesSummary(
  id: '0190e0d4-0000-7000-8000-0000000000e1',
  commonName: 'Jiboia',
  scientificName: 'Epipremnum aureum',
  referencePhoto: jiboiaImage,
);

/// An [IdentificationRepository] the test drives: [identify] answers
/// [identification] and [choose] answers [chosenSpecies], or they throw
/// [failure] when set. It records the calls.
///
/// Set [gate] to hold every call until the test completes it.
class FakeIdentificationRepository implements IdentificationRepository {
  FakeIdentificationRepository({
    this.identification = recognized,
    this.chosenSpecies = jiboiaSpecies,
  });

  Identification identification;
  SpeciesSummary chosenSpecies;

  /// Thrown by the next calls, until set back to null.
  IdentificationFailure? failure;

  /// When set, calls wait for it before answering.
  Completer<void>? gate;

  /// The photo id of every identification, in order.
  final identified = <String>[];

  /// Every choice, as `(identificationId, candidateIndex)`; null is "nenhuma
  /// destas".
  final choices = <(String, int?)>[];

  Future<void> _answer() async {
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }

  @override
  Future<Identification> identify(String photoId) async {
    identified.add(photoId);
    await _answer();
    return identification;
  }

  @override
  Future<SpeciesSummary> choose(
    String identificationId,
    int candidateIndex,
  ) async {
    choices.add((identificationId, candidateIndex));
    await _answer();
    return chosenSpecies;
  }

  @override
  Future<void> chooseNone(String identificationId) async {
    choices.add((identificationId, null));
    await _answer();
  }
}
