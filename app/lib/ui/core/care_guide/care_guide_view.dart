import 'package:flutter/material.dart';

import '../../../data/services/api/models/care_guide.dart';
import '../themes/colors.dart';
import 'wait_for_care_guide.dart';

/// The care guide as the species and plant screens show it (`M-especie`):
/// the rows "Rega · 1x por semana", "Luz · Meia-sombra" and "Como fazer
/// muda · Estaca", each with its icon in a mist square, then the full text
/// of each. Without a guide ([careGuide] null), says the tips are
/// unavailable.
class CareGuideView extends StatelessWidget {
  const CareGuideView({super.key, required this.careGuide});

  final CareGuide? careGuide;

  @override
  Widget build(BuildContext context) {
    final guide = careGuide;
    if (guide == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          careGuideUnavailableMessage,
          style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
        ),
      );
    }
    final cares = _cares(guide);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: 'Resumo dos cuidados',
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final care in cares) _CareRow(care: care)],
            ),
          ),
        ),
        for (final care in cares) ...[
          const SizedBox(height: 14),
          Text(
            care.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            care.tip.details,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF3A453D),
            ),
          ),
        ],
      ],
    );
  }

  static List<_Care> _cares(CareGuide guide) => [
    _Care('Rega', Icons.water_drop_outlined, guide.watering),
    _Care('Luz', Icons.wb_sunny_outlined, guide.light),
    _Care('Como fazer muda', Icons.content_cut, guide.propagation),
  ];
}

class _Care {
  const _Care(this.label, this.icon, this.tip);

  final String label;
  final IconData icon;
  final CareTip tip;
}

class _CareRow extends StatelessWidget {
  const _CareRow({required this.care});

  final _Care care;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.mist,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(care.icon, size: 18, color: AppColors.forest),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                care.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                care.tip.summary,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The loading state of a screen that waits for a care guide: a spinner,
/// with "gerando dicas…" below it while [generating].
class CareGuideLoading extends StatelessWidget {
  const CareGuideLoading({super.key, required this.generating});

  final bool generating;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (generating) ...[
            const SizedBox(height: 16),
            const Text(
              'gerando dicas…',
              style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
