// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'species.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Species _$SpeciesFromJson(Map<String, dynamic> json) => Species(
  id: json['id'] as String,
  commonName: json['commonName'] as String,
  scientificName: json['scientificName'] as String,
  referencePhoto: ReferencePhoto.fromJson(
    json['referencePhoto'] as Map<String, dynamic>,
  ),
  otherNames:
      (json['otherNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);
