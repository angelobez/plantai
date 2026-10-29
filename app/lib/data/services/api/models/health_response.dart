import 'package:json_annotation/json_annotation.dart';

part 'health_response.g.dart';

/// Body of `GET /v1/health` when the API and its database are up.
@JsonSerializable(createToJson: false)
class HealthResponse {
  const HealthResponse({
    required this.status,
    required this.apiVersion,
    required this.postgisVersion,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) =>
      _$HealthResponseFromJson(json);

  final String status;
  final String apiVersion;
  final String postgisVersion;
}
