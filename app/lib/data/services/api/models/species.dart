import 'package:json_annotation/json_annotation.dart';

import 'care_guide.dart';
import 'reference_photo.dart';

part 'species.g.dart';

/// A Catalog species as `GET /v1/species/:id` answers it, with its care
/// guide.
@JsonSerializable(createToJson: false)
class Species {
  const Species({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.referencePhoto,
    this.otherNames = const [],
    this.careGuide,
    this.careGuideStatus = CareGuideStatus.unavailable,
  });

  factory Species.fromJson(Map<String, dynamic> json) =>
      _$SpeciesFromJson(json);

  final String id;

  /// The primary common name; the scientific name while there is none.
  final String commonName;
  final String scientificName;
  final ReferencePhoto referencePhoto;

  /// The other common names, in alphabetical order.
  final List<String> otherNames;

  /// Null while [careGuideStatus] is [CareGuideStatus.unavailable].
  final CareGuide? careGuide;

  @JsonKey(unknownEnumValue: CareGuideStatus.unavailable)
  final CareGuideStatus careGuideStatus;
}
