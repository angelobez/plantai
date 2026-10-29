import 'package:flutter/material.dart';

/// The PlantAí leaf, drawn as a line icon on a 24 x 24 grid like the
/// Claude Design SVG (`M5 19C5 10 11 5 20 4c-1 9-6 15-15 15z` plus the
/// `M5 19l8-8` vein).
///
/// [color] defaults to the ambient [IconTheme], so it follows the tab bar's
/// selected and unselected colors.
class LeafIcon extends StatelessWidget {
  const LeafIcon({super.key, this.size, this.color, this.strokeWidth = 2});

  final double? size;
  final Color? color;

  /// In grid units (of 24), as in the SVG's `stroke-width`.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final side = size ?? iconTheme.size ?? 24;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(side),
        painter: _LeafPainter(
          color: color ?? iconTheme.color ?? Colors.black,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  /// The leaf in the 24 x 24 grid of the SVG.
  static final Path _leaf = Path()
    ..moveTo(5, 19)
    ..cubicTo(5, 10, 11, 5, 20, 4)
    ..cubicTo(19, 13, 14, 19, 5, 19)
    ..close()
    ..moveTo(5, 19)
    ..lineTo(13, 11);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.scale(scale);
    canvas.drawPath(
      _leaf,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LeafPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}
