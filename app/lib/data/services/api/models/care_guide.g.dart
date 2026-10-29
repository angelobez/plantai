// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'care_guide.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CareGuide _$CareGuideFromJson(Map<String, dynamic> json) => CareGuide(
  commonName: json['commonName'] as String,
  watering: CareTip.fromJson(json['watering'] as Map<String, dynamic>),
  light: CareTip.fromJson(json['light'] as Map<String, dynamic>),
  propagation: CareTip.fromJson(json['propagation'] as Map<String, dynamic>),
);

CareTip _$CareTipFromJson(Map<String, dynamic> json) => CareTip(
  summary: json['summary'] as String,
  details: json['details'] as String,
);
