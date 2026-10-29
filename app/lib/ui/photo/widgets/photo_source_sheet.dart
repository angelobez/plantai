import 'package:flutter/material.dart';

import '../../../data/services/photo_picker/photo_picker.dart';
import '../../core/themes/colors.dart';

/// Asks where the photo comes from: "Tirar foto" or "Escolher da galeria".
/// Null when the User closes the sheet.
///
/// The camera button, "Tirar outra" and every other way into the photo flow
/// open this, so the choice is always the same.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) =>
    showModalBottomSheet<PhotoSource>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => const _PhotoSourceSheet(),
    );

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final source in PhotoSource.values)
              ListTile(
                leading: Icon(switch (source) {
                  PhotoSource.camera => Icons.photo_camera_outlined,
                  PhotoSource.gallery => Icons.photo_library_outlined,
                }, color: AppColors.forest),
                title: Text(
                  photoSourceLabel(source),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                minTileHeight: 56,
                onTap: () => Navigator.of(context).pop(source),
              ),
          ],
        ),
      ),
    );
  }
}

/// The label of [source] in the sheet.
String photoSourceLabel(PhotoSource source) => switch (source) {
  PhotoSource.camera => 'Tirar foto',
  PhotoSource.gallery => 'Escolher da galeria',
};
