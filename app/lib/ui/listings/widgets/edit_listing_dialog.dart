import 'package:flutter/material.dart';

import '../../../data/services/api/models/listing.dart';
import '../../../domain/models/listing_changes.dart';
import '../../core/themes/colors.dart';
import '../view_models/new_listing_view_model.dart';
import 'quantity_stepper.dart';

/// "Editar anúncio": the quantity (1 to 99) and the note (up to 200
/// characters) of [listing], starting from the current ones. Completes with
/// only what changed (an emptied note comes as `''`, which clears it), or
/// with null when the User cancels or changes nothing.
Future<ListingChanges?> showEditListingDialog(
  BuildContext context, {
  required MyListing listing,
}) => showDialog<ListingChanges>(
  context: context,
  builder: (context) => _EditListingDialog(listing: listing),
);

class _EditListingDialog extends StatefulWidget {
  const _EditListingDialog({required this.listing});

  final MyListing listing;

  @override
  State<_EditListingDialog> createState() => _EditListingDialogState();
}

class _EditListingDialogState extends State<_EditListingDialog> {
  late int _quantity = widget.listing.quantity.clamp(
    NewListingViewModel.quantityMin,
    NewListingViewModel.quantityMax,
  );
  late final _note = TextEditingController(text: widget.listing.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final note = _note.text.trim();
    final quantityChanged = _quantity != widget.listing.quantity;
    final noteChanged = note != (widget.listing.note ?? '');
    Navigator.of(context).pop(
      quantityChanged || noteChanged
          ? ListingChanges(
              quantity: quantityChanged ? _quantity : null,
              note: noteChanged ? note : null,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar anúncio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Quantidade de mudas',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                QuantityStepper(
                  value: _quantity,
                  onDecrease: _quantity > NewListingViewModel.quantityMin
                      ? () => setState(() => _quantity--)
                      : null,
                  onIncrease: _quantity < NewListingViewModel.quantityMax
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Observação (opcional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _note,
              maxLength: NewListingViewModel.noteMaxLength,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ex.: pegar à tarde',
                hintStyle: TextStyle(color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
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
