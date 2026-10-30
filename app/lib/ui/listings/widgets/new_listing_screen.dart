import 'package:flutter/material.dart';

import '../../../data/services/api/models/listing.dart';
import '../../auth/widgets/form_message.dart';
import '../../auth/widgets/labeled_text_field.dart';
import '../../auth/widgets/submit_button.dart';
import '../../core/themes/colors.dart';
import '../../core/widgets/photo_image.dart';
import '../../photo/widgets/photo_source_sheet.dart';
import '../view_models/new_listing_view_model.dart';
import 'quantity_stepper.dart';

/// Novo anúncio, as in the Claude Design screen `M-novo-anuncio`: the photo
/// with "Tirar outra foto da muda", the editable name, the read-only
/// species, the quantity stepper (1 to 99) and the optional note with its
/// 200-character counter; "Publicar anúncio" at the bottom.
///
/// [onPublished] gets the listing once it is up. When the API asks for the
/// donation profile first, [onDonationProfileRequired] opens the Primeiro
/// anúncio and completes with whether the User saved it; then the screen
/// publishes again.
class NewListingScreen extends StatefulWidget {
  const NewListingScreen({
    super.key,
    required this.viewModel,
    required this.onPublished,
    required this.onDonationProfileRequired,
  });

  final NewListingViewModel viewModel;
  final ValueChanged<MyListing> onPublished;
  final Future<bool> Function() onDonationProfileRequired;

  @override
  State<NewListingScreen> createState() => _NewListingScreenState();
}

class _NewListingScreenState extends State<NewListingScreen> {
  late final _name = TextEditingController(text: widget.viewModel.commonName);
  late final _note = TextEditingController(text: widget.viewModel.note);

  NewListingViewModel get _viewModel => widget.viewModel;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _takeAnotherPhoto() async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;
    await _viewModel.takeAnotherPhoto(source);
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    switch (await _viewModel.publish()) {
      case Published(:final listing):
        if (mounted) widget.onPublished(listing);
      case DonationProfileNeeded():
        if (!mounted) return;
        if (await widget.onDonationProfileRequired() && mounted) {
          await _publish();
        }
      case NotPublished():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final species = _viewModel.species;
        final busy = _viewModel.isPublishing;
        return Scaffold(
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: IconButton(
                tooltip: 'Voltar',
                onPressed: () => Navigator.of(context).maybePop(),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.mist,
                  foregroundColor: AppColors.ink,
                  fixedSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.chevron_left, size: 24),
              ),
            ),
            centerTitle: true,
            title: const Text(
              'Doar mudas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _PhotoRow(
                  viewModel: _viewModel,
                  onTakeAnother: _takeAnotherPhoto,
                ),
                const SizedBox(height: 22),
                LabeledTextField(
                  label: 'Nome popular',
                  controller: _name,
                  errorText: _viewModel.nameError,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  enabled: !busy,
                  onChanged: _viewModel.updateName,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Espécie',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          species?.scientificName ?? 'Sem espécie',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: species == null
                                ? FontStyle.normal
                                : FontStyle.italic,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Quantidade de mudas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    QuantityStepper(
                      value: _viewModel.quantity,
                      onDecrease: !busy && _viewModel.canDecrease
                          ? _viewModel.decrease
                          : null,
                      onIncrease: !busy && _viewModel.canIncrease
                          ? _viewModel.increase
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Observação (opcional)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _note,
                  enabled: !busy,
                  maxLength: NewListingViewModel.noteMaxLength,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _viewModel.updateNote,
                  style: const TextStyle(fontSize: 15, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Ex.: pegar à tarde, muda em vaso de sorvete',
                    hintStyle: const TextStyle(color: AppColors.inkMuted),
                    contentPadding: const EdgeInsets.all(14),
                    counterStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                    border: _noteBorder(AppColors.border),
                    enabledBorder: _noteBorder(AppColors.border),
                    disabledBorder: _noteBorder(AppColors.divider),
                    focusedBorder: _noteBorder(AppColors.forest),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_viewModel.publishError != null) ...[
                    FormMessage(
                      error: _viewModel.publishError,
                      onRetry: _viewModel.canRetryPublish ? _publish : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  SubmitButton(
                    label: 'Publicar anúncio',
                    isLoading: busy,
                    onPressed: _viewModel.isTakingPhoto ? null : _publish,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fica visível por 30 dias para quem está a até 30 km.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static OutlineInputBorder _noteBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: 1.5),
  );
}

/// The listing's photo, where it came from, and "Tirar outra foto da muda".
class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.viewModel, required this.onTakeAnother});

  final NewListingViewModel viewModel;
  final VoidCallback onTakeAnother;

  @override
  Widget build(BuildContext context) {
    final error = viewModel.photoError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 96,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFE3EEE5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: viewModel.isTakingPhoto
                  ? const Center(child: CircularProgressIndicator())
                  : PhotoImage(photo: viewModel.photo),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viewModel.isPlantPhoto
                        ? 'Foto da planta do seu jardim'
                        : 'Foto da muda',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: viewModel.isTakingPhoto || viewModel.isPublishing
                        ? null
                        : onTakeAnother,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Tirar outra foto da muda'),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.mist,
                      foregroundColor: AppColors.forest,
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          FormMessage(error: error),
        ],
      ],
    );
  }
}
