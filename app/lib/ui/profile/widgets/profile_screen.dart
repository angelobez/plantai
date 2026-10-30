import 'package:flutter/material.dart';

import '../../../data/services/api/models/user_profile.dart';
import '../../auth/widgets/form_message.dart';
import '../../auth/widgets/labeled_text_field.dart';
import '../../core/themes/colors.dart';
import '../../core/widgets/tab_page.dart';
import '../../donation_profile/brazilian_phone.dart';
import '../view_models/profile_view_model.dart';

/// The Perfil tab, as in the Claude Design screen (`M-perfil`): the avatar,
/// name and e-mail (read only), the rows Nome, WhatsApp and Localização de
/// doação, "Sobre e créditos" and "Sair". The name is edited here; the phone
/// and the location open the donation-profile screen
/// ([onEditDonationProfile]).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.viewModel,
    required this.onAbout,
    required this.onEditDonationProfile,
  });

  static const notInformed = 'Não informado';

  final ProfileViewModel viewModel;

  /// Opens "Sobre e créditos".
  final VoidCallback onAbout;

  /// Opens the donation-profile screen for [UserProfile]'s phone and
  /// location.
  final ValueChanged<UserProfile> onEditDonationProfile;

  @override
  Widget build(BuildContext context) {
    return TabPage(
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final profile = viewModel.profile;
          if (profile != null) {
            return _ProfileView(
              profile: profile,
              viewModel: viewModel,
              onEditName: () => _editName(context, profile),
              onEditDonationProfile: () => onEditDonationProfile(profile),
              onAbout: onAbout,
            );
          }
          final error = viewModel.loadError;
          if (error != null && !viewModel.isLoading) {
            return _LoadError(message: error, onRetry: viewModel.load);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Future<void> _editName(BuildContext context, UserProfile profile) {
    viewModel.clearNameError();
    return showDialog<void>(
      context: context,
      builder: (context) =>
          _EditNameDialog(viewModel: viewModel, initialName: profile.name),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.profile,
    required this.viewModel,
    required this.onEditName,
    required this.onEditDonationProfile,
    required this.onAbout,
  });

  final UserProfile profile;
  final ProfileViewModel viewModel;
  final VoidCallback onEditName;
  final VoidCallback onEditDonationProfile;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final initial = profile.name.trim().isEmpty
        ? ''
        : profile.name.trim().characters.first.toUpperCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFC9DECD),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    profile.email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(height: 1),
        _InfoRow(label: 'Nome', value: profile.name, onEdit: onEditName),
        _InfoRow(
          label: 'WhatsApp',
          value: switch (profile.phone) {
            final phone? => displayPhone(phone),
            null => ProfileScreen.notInformed,
          },
          onEdit: onEditDonationProfile,
        ),
        _InfoRow(
          label: 'Localização de doação',
          value:
              profile.donationLocation?.neighborhood ??
              ProfileScreen.notInformed,
          onEdit: onEditDonationProfile,
        ),
        const SizedBox(height: 18),
        _AboutRow(onTap: onAbout),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: viewModel.isSigningOut ? null : viewModel.signOut,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              minimumSize: const Size(0, 52),
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Sair'),
          ),
        ),
      ],
    );
  }
}

/// A row of the profile: the muted [label] over the bold [value], with a
/// pencil when [onEdit] is given.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onEdit});

  final String label;
  final String value;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final onEdit = this.onEdit;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 60),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            const Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.inkMuted,
            ),
        ],
      ),
    );
    if (onEdit == null) return content;
    return Semantics(
      button: true,
      hint: 'Editar',
      child: InkWell(onTap: onEdit, child: content),
    );
  }
}

/// The "Sobre e créditos" row, with the chevron of a screen that opens.
class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text(
                  'Sobre e créditos',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormMessage(error: message),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.viewModel, required this.initialName});

  final ProfileViewModel viewModel;
  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _name = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await widget.viewModel.saveName(_name.text);
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final saving = widget.viewModel.isSavingName;
        return AlertDialog(
          title: const Text('Editar nome'),
          content: LabeledTextField(
            label: 'Nome',
            controller: _name,
            enabled: !saving,
            helperText: 'Nos anúncios, os vizinhos veem só o primeiro nome.',
            errorText: widget.viewModel.nameError,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
            onSubmitted: (_) => _save(),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving ? null : _save,
              // The theme's pill is as wide as the screen; not in a dialog.
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }
}
