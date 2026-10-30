import 'package:json_annotation/json_annotation.dart';

import 'photo.dart';
import 'species.dart';

part 'plant.g.dart';

/// One plant of Meu jardim as the list (`GET /v1/plants`) and the save
/// (`POST /v1/plants`) answer it.
@JsonSerializable(createToJson: false)
class PlantSummary {
  const PlantSummary({
    required this.id,
    required this.commonName,
    required this.photo,
    this.species,
  });

  factory PlantSummary.fromJson(Map<String, dynamic> json) =>
      _$PlantSummaryFromJson(json);

  final String id;

  /// The User's name for the plant (a free nickname).
  final String commonName;

  /// The photo the User saved it with.
  final Photo photo;

  /// Null for a plant saved with only a name.
  final PlantSpeciesSummary? species;
}

/// The species of a [PlantSummary].
@JsonSerializable(createToJson: false)
class PlantSpeciesSummary {
  const PlantSpeciesSummary({
    required this.id,
    required this.commonName,
    required this.scientificName,
    this.wateringSummary,
  });

  factory PlantSpeciesSummary.fromJson(Map<String, dynamic> json) =>
      _$PlantSpeciesSummaryFromJson(json);

  final String id;

  /// The primary common name; the scientific name while there is none.
  final String commonName;
  final String scientificName;

  /// The care guide's watering line ("1x por semana"); null until the guide
  /// is written.
  final String? wateringSummary;
}

/// One plant as the Tela da planta reads it (`GET /v1/plants/:id`).
@JsonSerializable(createToJson: false)
class Plant {
  const Plant({
    required this.id,
    required this.commonName,
    required this.photo,
    this.species,
  });

  factory Plant.fromJson(Map<String, dynamic> json) => _$PlantFromJson(json);

  final String id;

  /// The User's name for the plant (a free nickname).
  final String commonName;

  /// The photo the User saved it with.
  final Photo photo;

  /// The species as the Tela da espécie shows it, care guide included; null
  /// for a plant saved with only a name.
  final Species? species;

  /// This plant with [commonName] instead, as after a rename.
  Plant copyWith({String? commonName}) => Plant(
    id: id,
    commonName: commonName ?? this.commonName,
    photo: photo,
    species: species,
  );
}
