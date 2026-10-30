import 'package:json_annotation/json_annotation.dart';

part 'photo.g.dart';

/// A User's photo as every API response shows it (`{ id, url, expiresAt }`).
///
/// The [url] is presigned and changes on every response, so images are
/// cached by [id] (`PhotoImage`).
@JsonSerializable(createToJson: false)
class Photo {
  const Photo({required this.id, required this.url, required this.expiresAt});

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);

  final String id;
  final String url;

  /// When [url] stops working (1 h after the response).
  final DateTime expiresAt;
}
