import 'package:json_annotation/json_annotation.dart';

import 'reference_photo.dart';

part 'species_summary.g.dart';

/// A species as a search result (`GET /v1/species?q=`) shows it. Choosing an
/// identification candidate answers the same shape.
@JsonSerializable(createToJson: false)
class SpeciesSummary {
  const SpeciesSummary({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.referencePhoto,
    this.matchedAlternativeName,
  });

  factory SpeciesSummary.fromJson(Map<String, dynamic> json) =>
      _$SpeciesSummaryFromJson(json);

  final String id;

  /// The primary common name; the scientific name while there is none.
  final String commonName;
  final String scientificName;
  final ReferencePhoto referencePhoto;

  /// The other name the search term matched ("também chamada de…"), when it
  /// matched neither [commonName] nor [scientificName].
  final String? matchedAlternativeName;
}
