import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/services/api/models/photo.dart';
import '../../../data/services/api/models/reference_photo.dart';
import '../themes/colors.dart';

/// A User's photo from the API, cached by its id: the presigned URL changes
/// on every response, so a photo seen before shows at once, without
/// downloading it again.
class PhotoImage extends StatelessWidget {
  const PhotoImage({super.key, required this.photo, this.fit = BoxFit.cover});

  final Photo photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) =>
      _cachedImage(url: photo.url, cacheKey: photo.id, fit: fit);
}

/// A Catalog photo (a species' reference photo, an identification
/// candidate's), cached by its [ReferencePhoto.sourceUrl]: our own copies
/// come with a presigned URL that changes on every response, and the source
/// page is the one thing that names the photo.
class ReferencePhotoImage extends StatelessWidget {
  const ReferencePhotoImage({
    super.key,
    required this.photo,
    this.fit = BoxFit.cover,
  });

  final ReferencePhoto photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) =>
      _cachedImage(url: photo.url, cacheKey: photo.sourceUrl, fit: fit);
}

CachedNetworkImage _cachedImage({
  required String url,
  required String cacheKey,
  required BoxFit fit,
}) => CachedNetworkImage(
  imageUrl: url,
  cacheKey: cacheKey,
  fit: fit,
  placeholder: (context, url) => const ColoredBox(color: AppColors.mist),
  errorWidget: (context, url, error) => const ColoredBox(
    color: AppColors.mist,
    child: Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.inkMuted,
      ),
    ),
  ),
);
