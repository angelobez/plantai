import 'package:json_annotation/json_annotation.dart';

import 'reference_photo.dart';

part 'identification.g.dart';

/// Whether Pl@ntNet recognized the plant in the photo.
enum IdentificationResult {
  @JsonValue('recognized')
  recognized,

  /// No candidate, or the best one too unsure: "Foto não reconhecida". Not an
  /// error, and it still counts against the daily limit.
  @JsonValue('not_recognized')
  notRecognized,
}

/// The answer of `POST /v1/identifications`.
@JsonSerializable(createToJson: false)
class Identification {
  const Identification({
    required this.id,
    required this.result,
    required this.candidates,
    required this.remainingToday,
  });

  factory Identification.fromJson(Map<String, dynamic> json) =>
      _$IdentificationFromJson(json);

  final String id;
  final IdentificationResult result;

  /// Up to 3, best first; empty when [result] is
  /// [IdentificationResult.notRecognized].
  final List<Candidate> candidates;

  /// Identifications the User still has today.
  final int remainingToday;
}

/// A species Pl@ntNet proposes for the photo.
@JsonSerializable(createToJson: false)
class Candidate {
  const Candidate({
    required this.scientificName,
    required this.commonName,
    required this.score,
    required this.images,
  });

  factory Candidate.fromJson(Map<String, dynamic> json) =>
      _$CandidateFromJson(json);

  final String scientificName;

  /// Null when Pl@ntNet had no name that looks like one.
  final String? commonName;

  /// From 0 to 1.
  final double score;

  /// Pl@ntNet photos of the species, with their credit.
  final List<ReferencePhoto> images;

  /// What the card shows as the name: [commonName], or the scientific name.
  String get displayName => commonName ?? scientificName;
}
