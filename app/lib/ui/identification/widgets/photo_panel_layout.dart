import 'package:flutter/material.dart';

import '../../../data/services/api/models/photo.dart';
import '../../core/themes/colors.dart';
import '../../core/widgets/leaf_icon.dart';
import '../../core/widgets/photo_image.dart';

const _panelOverlap = 26.0;

/// The layout of Foto não reconhecida and Limite diário (`M-nao-reconhecida`,
/// `M-limite`): the User's [photo] on top with "Voltar", and a white panel
/// over its bottom edge holding [children].
class PhotoPanelLayout extends StatelessWidget {
  const PhotoPanelLayout({
    super.key,
    required this.photo,
    required this.children,
  });

  /// The photo being identified; a leaf when the route did not get it.
  final Photo? photo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: const Color(0xFF9AA89C),
                child: photo == null
                    ? const Center(
                        child: LeafIcon(
                          size: 80,
                          strokeWidth: 1.1,
                          color: Color(0xFFE6ECE7),
                        ),
                      )
                    : PhotoImage(photo: photo),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: IconButton(
                      tooltip: 'Voltar',
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.92),
                        foregroundColor: AppColors.ink,
                        fixedSize: const Size.square(44),
                      ),
                      icon: const Icon(Icons.chevron_left, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -_panelOverlap),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_panelOverlap),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The 22/w800 title of the panel.
class PanelTitle extends StatelessWidget {
  const PanelTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    ),
  );
}

/// "Salvar só com o nome", shown disabled while [onPressed] is null (the
/// flow that saves arrives with the garden).
class SaveNameOnlyButton extends StatelessWidget {
  const SaveNameOnlyButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
    child: const Text('Salvar só com o nome'),
  );
}
