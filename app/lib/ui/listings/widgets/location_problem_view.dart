import 'package:flutter/material.dart';

import '../../core/widgets/empty_state.dart';
import '../../donation_profile/view_models/donation_profile_view_model.dart'
    show LocationProblem;

/// Localização negada, as in the Claude Design screen `M-localizacao`: why
/// the app needs the approximate location, with "Tentar de novo". Refused
/// for good, the main button opens the Android settings ([onOpenSettings]);
/// with the location off, a second button opens the location switch.
class LocationProblemView extends StatelessWidget {
  const LocationProblemView({
    super.key,
    required this.problem,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final LocationProblem problem;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  static const _why =
      'Ela serve só para achar mudas a até 30 km. Usamos a localização '
      'aproximada e não guardamos onde você está.';

  @override
  Widget build(BuildContext context) {
    final retry = FilledButton(
      onPressed: onRetry,
      child: const Text('Tentar de novo'),
    );
    final (title, message, action) = switch (problem) {
      LocationProblem.denied => ('Precisamos da sua localização', _why, retry),
      LocationProblem.deniedForever => (
        'Precisamos da sua localização',
        '$_why Libere a localização do PlantAí nas configurações do '
            'Android.',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: onOpenSettings,
              child: const Text('Abrir as configurações do Android'),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
      LocationProblem.serviceDisabled => (
        'Ligue a localização',
        'A localização do celular está desligada. Ligue para achar mudas a '
            'até 30 km.',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            retry,
            const SizedBox(height: 4),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Abrir as configurações de localização'),
            ),
          ],
        ),
      ),
      LocationProblem.unavailable => (
        'Não achamos a sua localização',
        'Confira se a localização do celular está ligada e tente de novo.',
        retry,
      ),
    };
    return EmptyState(
      icon: const Icon(Icons.location_off_outlined),
      tileColor: const Color(0xFFF5EFE6),
      iconColor: const Color(0xFF8A5A12),
      title: title,
      message: message,
      action: action,
    );
  }
}
