import 'package:flutter/material.dart';

import '../../../data/services/api/models/photo.dart';
import '../../../data/services/photo_picker/photo_picker.dart';
import '../../auth/widgets/form_message.dart';
import '../../core/themes/colors.dart';
import '../../core/widgets/leaf_icon.dart';
import '../view_models/photo_view_model.dart';
import 'photo_action_tile.dart';
import 'photo_source_sheet.dart';

/// Foto, as in the Claude Design screen (`M-foto`): the photo on top with
/// "Fechar" and "Tirar outra", and a white panel over it with "Que planta é
/// essa?", "Identificar pela foto" and "Buscar pelo nome". The photo is sent
/// as soon as it is picked; both actions wait for it.
///
/// It opens the picker for [initialSource] when it appears, and closes
/// itself ([onClose]) when the User cancels before there is any photo.
class PhotoScreen extends StatefulWidget {
  const PhotoScreen({
    super.key,
    required this.viewModel,
    required this.initialSource,
    required this.onClose,
    this.onIdentify,
    this.onSearchByName,
  });

  final PhotoViewModel viewModel;
  final PhotoSource initialSource;

  /// Gives up: back to where the User was.
  final VoidCallback onClose;

  /// "Identificar pela foto", with the photo as the API stored it. It
  /// completes when the User is back on Foto, with the source of another
  /// photo when they asked for one ("Tirar outra foto" on Foto não
  /// reconhecida), which Foto then opens. The actions are enabled once the
  /// photo is sent, even before a flow is plugged in here.
  final Future<PhotoSource?> Function(Photo photo)? onIdentify;

  /// "Buscar pelo nome", with the photo as the API stored it.
  final ValueChanged<Photo>? onSearchByName;

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  PhotoViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _pick(widget.initialSource);
  }

  Future<void> _pick(PhotoSource source) async {
    final hasSomething = await _viewModel.pick(source);
    if (!hasSomething && mounted) widget.onClose();
  }

  Future<void> _identify(Photo photo) async {
    final source = await widget.onIdentify?.call(photo);
    if (source != null && mounted) await _pick(source);
  }

  Future<void> _pickAnother() async {
    final source = await showPhotoSourceSheet(context);
    if (source != null && mounted) await _pick(source);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _PhotoArea(
                viewModel: _viewModel,
                onClose: widget.onClose,
                onPickAnother: _pickAnother,
              ),
            ),
            // Over the photo's bottom edge, as in the design.
            Transform.translate(
              offset: const Offset(0, -_panelOverlap),
              child: _Panel(
                viewModel: _viewModel,
                onGallery: () => _pick(PhotoSource.gallery),
                onIdentify: widget.onIdentify == null ? null : _identify,
                onSearchByName: widget.onSearchByName,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _panelOverlap = 26.0;

/// The preview, or a leaf while there is no photo yet.
class _PhotoArea extends StatelessWidget {
  const _PhotoArea({
    required this.viewModel,
    required this.onClose,
    required this.onPickAnother,
  });

  final PhotoViewModel viewModel;
  final VoidCallback onClose;
  final VoidCallback onPickAnother;

  @override
  Widget build(BuildContext context) {
    final picked = viewModel.picked;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: const Color(0xFF7FA886),
          child: picked == null
              ? const Center(
                  child: LeafIcon(
                    size: 80,
                    strokeWidth: 1.1,
                    color: Color(0xFFE3EEE5),
                  ),
                )
              : Image.memory(
                  picked.bytes,
                  key: const Key('photo-preview'),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  semanticLabel: 'A foto escolhida',
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _RoundButton(
                tooltip: 'Fechar',
                onPressed: onClose,
                child: const Icon(Icons.close, size: 20),
              ),
            ),
          ),
        ),
        if (picked != null)
          Positioned(
            right: 16,
            bottom: _panelOverlap + 18,
            child: _PillButton(
              label: 'Tirar outra',
              onPressed: viewModel.isPicking ? null : onPickAnother,
            ),
          ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.viewModel,
    required this.onGallery,
    required this.onIdentify,
    required this.onSearchByName,
  });

  final PhotoViewModel viewModel;
  final VoidCallback onGallery;
  final ValueChanged<Photo>? onIdentify;
  final ValueChanged<Photo>? onSearchByName;

  @override
  Widget build(BuildContext context) {
    final photo = viewModel.photo;
    final pickError = viewModel.pickError;
    final uploadError = viewModel.uploadError;
    return DecoratedBox(
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
            children: [
              const Text(
                'Que planta é essa?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 16),
              if (pickError != null) ...[
                FormMessage(error: pickError),
                if (viewModel.cameraDenied) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: viewModel.isPicking ? null : onGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Escolher da galeria'),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              if (uploadError != null) ...[
                FormMessage(
                  error: uploadError,
                  onRetry: viewModel.canRetryUpload
                      ? viewModel.retryUpload
                      : null,
                ),
                const SizedBox(height: 12),
              ] else if (viewModel.isUploading) ...[
                const _Sending(),
                const SizedBox(height: 12),
              ],
              PhotoActionTile(
                icon: Icons.photo_camera_outlined,
                title: 'Identificar pela foto',
                primary: true,
                onTap: photo == null ? null : () => onIdentify?.call(photo),
              ),
              const SizedBox(height: 12),
              PhotoActionTile(
                icon: Icons.search,
                title: 'Buscar pelo nome',
                subtitle: 'Se você já sabe o nome popular ou científico',
                onTap: photo == null ? null : () => onSearchByName?.call(photo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sending extends StatelessWidget {
  const _Sending();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: const Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'Enviando a foto…',
            style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// The white circle over the photo ("Fechar").
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        foregroundColor: AppColors.ink,
        fixedSize: const Size.square(44),
      ),
      icon: child,
    );
  }
}

/// The white pill over the photo ("Tirar outra").
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        foregroundColor: AppColors.ink,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }
}
