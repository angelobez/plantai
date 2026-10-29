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
  careGuide: json['careGuide'] == null
      ? null
      : CareGuide.fromJson(json['careGuide'] as Map<String, dynamic>),
  careGuideStatus:
      $enumDecodeNullable(
        _$CareGuideStatusEnumMap,
        json['careGuideStatus'],
        unknownValue: CareGuideStatus.unavailable,
      ) ??
      CareGuideStatus.unavailable,
);

const _$CareGuideStatusEnumMap = {
  CareGuideStatus.ready: 'ready',
  CareGuideStatus.unavailable: 'unavailable',
};
