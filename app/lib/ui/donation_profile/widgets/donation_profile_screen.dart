import 'package:flutter/material.dart';

import '../../../data/services/api/models/user_profile.dart';
import '../../auth/widgets/form_message.dart';
import '../../auth/widgets/labeled_text_field.dart';
import '../../auth/widgets/submit_button.dart';
import '../../core/themes/colors.dart';
import '../brazilian_phone.dart';
import '../view_models/donation_profile_view_model.dart';

/// The donation profile, as in the Claude Design screen
/// `M-primeiro-anuncio`: the WhatsApp phone (masked, with "Testar no
/// WhatsApp"), "Usar minha localização" with the suggested neighborhood in an
/// editable field, and the privacy note.
///
/// The same screen serves the Perfil ([DonationProfileScreen.profile]) and
/// the Primeiro anúncio before the listing form
/// ([DonationProfileScreen.firstListing]); only the title and the button
/// change. [onSaved] gets the profile as the API saved it.
class DonationProfileScreen extends StatefulWidget {
  const DonationProfileScreen({
    super.key,
    required this.viewModel,
    required this.title,
    required this.submitLabel,
    required this.onSaved,
  });

  /// Opened from the Perfil, to change the phone and the location.
  const DonationProfileScreen.profile({
    super.key,
    required this.viewModel,
    required this.onSaved,
  }) : title = 'Perfil de doação',
       submitLabel = 'Salvar';

  /// The Primeiro anúncio, before the form of a first listing.
  const DonationProfileScreen.firstListing({
    super.key,
    required this.viewModel,
    required this.onSaved,
  }) : title = 'Antes de doar',
       submitLabel = 'Continuar';

  final DonationProfileViewModel viewModel;
  final String title;
  final String submitLabel;
  final ValueChanged<UserProfile> onSaved;

  @override
  State<DonationProfileScreen> createState() => _DonationProfileScreenState();
}

class _DonationProfileScreenState extends State<DonationProfileScreen> {
  late final _phone = TextEditingController(text: widget.viewModel.phone);
  late final _neighborhood = TextEditingController(
    text: widget.viewModel.neighborhood,
  );

  DonationProfileViewModel get _viewModel => widget.viewModel;

  @override
  void dispose() {
    _phone.dispose();
    _neighborhood.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    await _viewModel.useMyLocation();
    // The suggestion replaces the field; the User may still correct it.
    if (mounted && _neighborhood.text != _viewModel.neighborhood) {
      _neighborhood.text = _viewModel.neighborhood;
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await _viewModel.save();
    if (saved != null && mounted) widget.onSaved(saved);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => Scaffold(
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
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Como os vizinhos falam com você e de onde você doa',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.25,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              LabeledTextField(
                label: 'WhatsApp',
                controller: _phone,
                hintText: '(11) 98765-4321',
                helperText: 'Celular com DDD; o +55 é opcional.',
                errorText: _viewModel.phoneError,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: const [BrazilianPhoneInputFormatter()],
                enabled: !_viewModel.isSaving,
                onChanged: _viewModel.updatePhone,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _Pill(
                  icon: Icons.chat_outlined,
                  label: 'Testar no WhatsApp',
                  onPressed: _viewModel.testOnWhatsApp,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Localização de doação',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              if (_viewModel.hasPosition)
                _FoundLocation(controller: _neighborhood, viewModel: _viewModel)
              else
                _AskLocation(
                  viewModel: _viewModel,
                  onUseMyLocation: _useMyLocation,
                ),
              const SizedBox(height: 18),
              const _PrivacyNote(),
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
                if (_viewModel.saveError != null) ...[
                  FormMessage(
                    error: _viewModel.saveError,
                    onRetry: _viewModel.canRetrySave ? _save : null,
                  ),
                  const SizedBox(height: 12),
                ],
                SubmitButton(
                  label: widget.submitLabel,
                  isLoading: _viewModel.isSaving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Before a position: "Usar minha localização", the neighborhood saved
/// before (if any) and why the last try found nothing.
class _AskLocation extends StatelessWidget {
  const _AskLocation({required this.viewModel, required this.onUseMyLocation});

  final DonationProfileViewModel viewModel;
  final VoidCallback onUseMyLocation;

  @override
  Widget build(BuildContext context) {
    final current = viewModel.currentNeighborhood;
    final error = viewModel.locationError;
    final problem = viewModel.locationProblem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current != null) ...[
          Text(
            'Hoje: $current. Se você mudou de lugar, use a localização de '
            'novo.',
            style: const TextStyle(fontSize: 14, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: viewModel.isLocating ? null : onUseMyLocation,
          icon: viewModel.isLocating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          label: const Text('Usar minha localização'),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          FormMessage(error: error),
        ],
        if (problem == LocationProblem.deniedForever ||
            problem == LocationProblem.serviceDisabled)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: viewModel.openSettings,
              child: Text(
                problem == LocationProblem.deniedForever
                    ? 'Abrir as configurações do Android'
                    : 'Ligar a localização',
              ),
            ),
          ),
      ],
    );
  }
}

/// After a position: the card with the neighborhood the geocoder suggested,
/// in a field the User may correct.
class _FoundLocation extends StatelessWidget {
  const _FoundLocation({required this.controller, required this.viewModel});

  final TextEditingController controller;
  final DonationProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, size: 18, color: AppColors.forest),
              SizedBox(width: 6),
              Text(
                'Localização encontrada pelo GPS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LabeledTextField(
            label: 'Bairro',
            controller: controller,
            errorText: viewModel.neighborhoodError,
            helperText: viewModel.neighborhoodNotFound
                ? 'Não achamos o bairro. Digite o seu.'
                : 'Se não for o seu, corrija.',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            enabled: !viewModel.isSaving,
            onChanged: viewModel.updateNeighborhood,
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 18, color: AppColors.inkMuted),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Só mostramos o bairro e a distância aproximada, nunca o seu '
            'endereço.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// A small mist pill with an icon, like "Testar no WhatsApp".
class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.mist,
        foregroundColor: AppColors.forest,
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}
