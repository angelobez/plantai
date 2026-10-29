// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Identification _$IdentificationFromJson(Map<String, dynamic> json) =>
    Identification(
      id: json['id'] as String,
      result: $enumDecode(_$IdentificationResultEnumMap, json['result']),
      candidates: (json['candidates'] as List<dynamic>)
          .map((e) => Candidate.fromJson(e as Map<String, dynamic>))
          .toList(),
      remainingToday: (json['remainingToday'] as num).toInt(),
    );

const _$IdentificationResultEnumMap = {
  IdentificationResult.recognized: 'recognized',
  IdentificationResult.notRecognized: 'not_recognized',
};

Candidate _$CandidateFromJson(Map<String, dynamic> json) => Candidate(
  scientificName: json['scientificName'] as String,
  commonName: json['commonName'] as String?,
  score: (json['score'] as num).toDouble(),
  images: (json['images'] as List<dynamic>)
      .map((e) => ReferencePhoto.fromJson(e as Map<String, dynamic>))
      .toList(),
);
