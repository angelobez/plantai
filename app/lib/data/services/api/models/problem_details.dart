import 'package:json_annotation/json_annotation.dart';

part 'problem_details.g.dart';

/// An `application/problem+json` error body (RFC 9457) with the API's `code`.
@JsonSerializable(createToJson: false)
class ProblemDetails {
  const ProblemDetails({required this.status, required this.code, this.title});

  factory ProblemDetails.fromJson(Map<String, dynamic> json) =>
      _$ProblemDetailsFromJson(json);

  final int status;
  final String code;
  final String? title;
}
