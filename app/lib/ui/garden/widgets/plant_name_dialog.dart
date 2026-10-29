import 'package:flutter/material.dart';

import '../../auth/widgets/labeled_text_field.dart';

/// The longest plant name, as the API takes it.
const plantNameMaxLength = 80;

/// Asks the name of a plant ("Nome da planta"), starting from [initialName].
/// Completes with the name, trimmed and 1 to 80 characters long, or with
/// null when the User cancels.
Future<String?> showPlantNameDialog(
  BuildContext context, {
  String initialName = '',
  String title = 'Nome da planta',
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _PlantNameDialog(initialName: initialName, title: title),
);

class _PlantNameDialog extends StatefulWidget {
  const _PlantNameDialog({required this.initialName, required this.title});

  final String initialName;
  final String title;

  @override
  State<_PlantNameDialog> createState() => _PlantNameDialogState();
}

class _PlantNameDialogState extends State<_PlantNameDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final error = name.isEmpty
        ? 'Dê um nome para a planta.'
        : name.length > plantNameMaxLength
        ? 'Use até $plantNameMaxLength caracteres.'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: LabeledTextField(
        label: 'Nome da planta',
        controller: _name,
        helperText: 'Um apelido livre, como "Jiboia da sala".',
        errorText: _error,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          // The theme's pill is as wide as the screen; not in a dialog.
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
