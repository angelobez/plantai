import 'package:flutter/material.dart';

import '../themes/colors.dart';
import 'leaf_icon.dart';

/// The PlantAí logo: the leaf, "Plant" and the "Aí" tag in dark green.
///
/// [fontSize] scales the whole logo; the default (25) is the size of the tab
/// headers. The Login screen uses a bigger one.
class PlantaiLogo extends StatelessWidget {
  const PlantaiLogo({super.key, this.fontSize = 25, this.showLeaf = true});

  final double fontSize;

  /// The Login screen shows the leaf apart, in the app icon tile.
  final bool showLeaf;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -fontSize * 0.04,
      color: AppColors.ink,
      height: 1.2,
    );
    return Semantics(
      label: 'PlantAí',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLeaf) ...[
            LeafIcon(
              size: fontSize * 1.04,
              color: AppColors.forest,
              strokeWidth: 2.2,
            ),
            SizedBox(width: fontSize * 0.24),
          ],
          Text('Plant', style: textStyle),
          SizedBox(width: fontSize * 0.08),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.forest,
              borderRadius: BorderRadius.circular(fontSize * 0.36),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: fontSize * 0.28),
              child: Text('Aí', style: textStyle.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
