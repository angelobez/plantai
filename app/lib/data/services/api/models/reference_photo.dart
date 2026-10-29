import 'package:json_annotation/json_annotation.dart';

part 'reference_photo.g.dart';

/// A Catalog photo with its credit (`{ url, author, license, sourceUrl }`):
/// the reference photo of a species, or of an identification candidate.
///
/// The [url] may be presigned and change on every response, so images are
/// cached by [sourceUrl] (`ReferencePhotoImage`).
@JsonSerializable(createToJson: false)
class ReferencePhoto {
  const ReferencePhoto({
    required this.url,
    required this.author,
    required this.license,
    required this.sourceUrl,
  });

  factory ReferencePhoto.fromJson(Map<String, dynamic> json) =>
      _$ReferencePhotoFromJson(json);

  final String url;
  final String author;

  /// Such as `CC BY-SA 4.0`.
  final String license;

  /// The page of the photo, which the credit links to.
  final String sourceUrl;
}
