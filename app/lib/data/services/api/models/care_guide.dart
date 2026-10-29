import 'package:json_annotation/json_annotation.dart';

part 'care_guide.g.dart';

/// Whether a response brought the care guide. `unavailable` means Claude
/// failed this time; opening the species again tries once more.
@JsonEnum()
enum CareGuideStatus { ready, unavailable }

/// A species' care guide (Dicas de cuidado), written by Claude once and the
/// same for everyone. The species and plant screens show it.
@JsonSerializable(createToJson: false)
class CareGuide {
  const CareGuide({
    required this.commonName,
    required this.watering,
    required this.light,
    required this.propagation,
  });

  factory CareGuide.fromJson(Map<String, dynamic> json) =>
      _$CareGuideFromJson(json);

  /// The common name Claude gave the species.
  final String commonName;

  /// Rega.
  final CareTip watering;

  /// Luz.
  final CareTip light;

  /// Como fazer muda.
  final CareTip propagation;
}

/// One care: a short line for the row ("1x por semana") and the full text.
@JsonSerializable(createToJson: false)
class CareTip {
  const CareTip({required this.summary, required this.details});

  factory CareTip.fromJson(Map<String, dynamic> json) =>
      _$CareTipFromJson(json);

  final String summary;
  final String details;
}
