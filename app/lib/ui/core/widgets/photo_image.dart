import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/services/api/models/photo.dart';
import '../themes/colors.dart';

/// A User's photo from the API, cached by its id: the presigned URL changes
/// on every response, so a photo seen before shows at once, without
/// downloading it again.
class PhotoImage extends StatelessWidget {
  const PhotoImage({super.key, required this.photo, this.fit = BoxFit.cover});

  final Photo photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: photo.url,
      cacheKey: photo.id,
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
  }
}
