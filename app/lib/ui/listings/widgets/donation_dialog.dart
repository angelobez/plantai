import 'package:flutter/material.dart';

import '../../../data/services/api/models/listing.dart';
import '../listing_texts.dart';
import 'quantity_stepper.dart';

/// "Doei algumas": how many seedlings of [listing] went, from 1 up to its
/// current quantity, starting at 1. Completes with the count, or with null
/// when the User cancels.
Future<int?> showDonationDialog(
  BuildContext context, {
  required MyListing listing,
}) => showDialog<int>(
  context: context,
  builder: (context) => _DonationDialog(listing: listing),
);

class _DonationDialog extends StatefulWidget {
  const _DonationDialog({required this.listing});

  final MyListing listing;

  @override
  State<_DonationDialog> createState() => _DonationDialogState();
}

class _DonationDialogState extends State<_DonationDialog> {
  int _count = 1;

  int get _max => widget.listing.quantity;

  /// Clamped, as taps can come faster than the stepper rebuilds.
  void _setCount(int count) => setState(() => _count = count.clamp(1, _max));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Doei algumas'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quantas mudas você doou?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('O anúncio tem ${seedlingCount(_max)}.'),
          const SizedBox(height: 14),
          Center(
            child: QuantityStepper(
              value: _count,
              onDecrease: _count > 1 ? () => _setCount(_count - 1) : null,
              onIncrease: _count < _max ? () => _setCount(_count + 1) : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_count),
          // The theme's pill is as wide as the screen; not in a dialog.
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
