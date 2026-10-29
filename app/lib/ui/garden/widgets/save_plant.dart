import 'package:flutter/material.dart';

import '../../../data/repositories/garden/garden_repository.dart';
import '../../../data/services/api/models/plant.dart';
import '../../../domain/models/garden_failure.dart';
import '../../../domain/models/new_plant.dart';
import '../garden_failure_message.dart';

/// Saves [plant] in Meu jardim from any screen of the photo flow ("Salvar no
/// meu jardim", "Salvar só com o nome"), then calls [onSaved] with it.
///
/// While saving, a dialog that cannot be closed covers the screen, so the
/// same photo is never saved twice. A failure shows a [SnackBar] with the
/// message and, when trying again makes sense, "Tentar de novo".
Future<void> savePlant(
  BuildContext context, {
  required GardenRepository gardenRepository,
  required NewPlant plant,
  required ValueChanged<PlantSummary> onSaved,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(canPop: false, child: _SavingDialog()),
  );
  try {
    final saved = await gardenRepository.create(plant);
    navigator.pop();
    onSaved(saved);
  } on GardenFailure catch (failure) {
    navigator.pop();
    final canRetry = failure != GardenFailure.notFound;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          gardenFailureMessage(
            failure,
            notFound: 'Essa foto não está mais disponível. Tire outra foto.',
          ),
        ),
        action: canRetry && context.mounted
            ? SnackBarAction(
                label: 'Tentar de novo',
                onPressed: () {
                  if (!context.mounted) return;
                  savePlant(
                    context,
                    gardenRepository: gardenRepository,
                    plant: plant,
                    onSaved: onSaved,
                  );
                },
              )
            : null,
      ),
    );
  }
}

class _SavingDialog extends StatelessWidget {
  const _SavingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 16),
          Expanded(child: Text('Salvando no seu jardim…')),
        ],
      ),
    );
  }
}
