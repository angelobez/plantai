// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlantSummary _$PlantSummaryFromJson(Map<String, dynamic> json) => PlantSummary(
  id: json['id'] as String,
  commonName: json['commonName'] as String,
  photo: Photo.fromJson(json['photo'] as Map<String, dynamic>),
  species: json['species'] == null
      ? null
      : PlantSpeciesSummary.fromJson(json['species'] as Map<String, dynamic>),
);

PlantSpeciesSummary _$PlantSpeciesSummaryFromJson(Map<String, dynamic> json) =>
    PlantSpeciesSummary(
      id: json['id'] as String,
      commonName: json['commonName'] as String,
      scientificName: json['scientificName'] as String,
      wateringSummary: json['wateringSummary'] as String?,
    );

Plant _$PlantFromJson(Map<String, dynamic> json) => Plant(
  id: json['id'] as String,
  commonName: json['commonName'] as String,
  photo: Photo.fromJson(json['photo'] as Map<String, dynamic>),
  species: json['species'] == null
      ? null
      : Species.fromJson(json['species'] as Map<String, dynamic>),
);
