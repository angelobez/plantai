import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';

/// "−" [value] "+", for how many seedlings. [onDecrease] or [onIncrease]
/// null disables that button (at a limit, or while busy).
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Menos uma',
            onPressed: onDecrease,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              fixedSize: const Size.square(40),
            ),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Mais uma',
            onPressed: onIncrease,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              fixedSize: const Size.square(40),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
