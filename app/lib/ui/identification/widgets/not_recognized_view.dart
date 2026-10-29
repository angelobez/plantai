import 'package:flutter/material.dart';

import '../../../data/services/api/models/photo.dart';
import '../../core/themes/colors.dart';
import 'photo_panel_layout.dart';

/// Foto não reconhecida, as in the Claude Design screen
/// (`M-nao-reconhecida`): the photo was not a plant, or too unsure. The User
/// takes another photo, searches by name, or saves the plant with just a
/// name.
class NotRecognizedView extends StatelessWidget {
  const NotRecognizedView({
    super.key,
    required this.photo,
    required this.onTakeAnother,
    required this.onSearchByName,
    required this.onSaveNameOnly,
  });

  final Photo? photo;
  final VoidCallback onTakeAnother;
  final VoidCallback onSearchByName;

  /// Disabled while null.
  final VoidCallback? onSaveNameOnly;

  @override
  Widget build(BuildContext context) {
    return PhotoPanelLayout(
      photo: photo,
      children: [
        const PanelTitle('Não consegui reconhecer'),
        const SizedBox(height: 8),
        const Text(
          'Tente outra foto: uma folha ou flor de perto, com boa luz.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onTakeAnother,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Tirar outra foto'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onSearchByName,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.mist,
            foregroundColor: AppColors.ink,
          ),
          child: const Text('Buscar pelo nome'),
        ),
        const SizedBox(height: 4),
        SaveNameOnlyButton(onPressed: onSaveNameOnly),
      ],
    );
  }
}
