import 'package:flutter/material.dart';

import '../../../data/services/api/models/photo.dart';
import '../../photo/widgets/photo_action_tile.dart';
import 'photo_panel_layout.dart';

/// Limite diário, as in the Claude Design screen (`M-limite`): Foto again,
/// with "Identificar pela foto" off for today and the search still there.
class DailyLimitView extends StatelessWidget {
  const DailyLimitView({
    super.key,
    required this.photo,
    required this.onSearchByName,
    required this.onSaveNameOnly,
  });

  final Photo? photo;
  final VoidCallback onSearchByName;

  /// Disabled while null.
  final VoidCallback? onSaveNameOnly;

  @override
  Widget build(BuildContext context) {
    return PhotoPanelLayout(
      photo: photo,
      children: [
        const PanelTitle('Que planta é essa?'),
        const SizedBox(height: 16),
        const PhotoActionTile(
          icon: Icons.photo_camera_outlined,
          title: 'Identificar pela foto',
          subtitle: 'Você usou suas 10 identificações de hoje; amanhã tem mais',
          primary: true,
          onTap: null,
        ),
        const SizedBox(height: 12),
        PhotoActionTile(
          icon: Icons.search,
          title: 'Buscar pelo nome',
          subtitle: 'A busca continua liberada',
          onTap: onSearchByName,
        ),
        const SizedBox(height: 4),
        SaveNameOnlyButton(onPressed: onSaveNameOnly),
      ],
    );
  }
}
