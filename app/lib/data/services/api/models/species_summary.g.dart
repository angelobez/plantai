// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'species_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpeciesSummary _$SpeciesSummaryFromJson(Map<String, dynamic> json) =>
    SpeciesSummary(
      id: json['id'] as String,
      commonName: json['commonName'] as String,
      scientificName: json['scientificName'] as String,
      referencePhoto: ReferencePhoto.fromJson(
        json['referencePhoto'] as Map<String, dynamic>,
      ),
      matchedAlternativeName: json['matchedAlternativeName'] as String?,
    );
