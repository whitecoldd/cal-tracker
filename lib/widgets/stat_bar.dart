import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A segmented HUD bar — Vitality, Toxicity, Stamina, Adrenaline.
///
/// Segments rather than a smooth fill: it reads as a game meter, and it makes
/// small changes legible without printing a decimal.
class StatBar extends StatelessWidget {
  const StatBar({
    required this.label,
    required this.value,
    required this.color,
    this.max = 100,
    this.valueLabel,
    this.segments = 20,
    this.height = 10,
    super.key,
  });

  final String label;
  final double value;
  final double max;
  final Color color;

  /// Text shown at the right of the label row. Defaults to `value/max`.
  final String? valueLabel;

  final int segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(), style: Type.label()),
            Text(
              valueLabel ?? '${value.round()} / ${max.round()}',
              style: Type.label(color: color),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _SegmentPainter(
              fraction: fraction,
              color: color,
              segments: segments,
            ),
          ),
        ),
      ],
    );
  }
}

class _SegmentPainter extends CustomPainter {
  const _SegmentPainter({
    required this.fraction,
    required this.color,
    required this.segments,
  });

  final double fraction;
  final Color color;
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final segW = (size.width - gap * (segments - 1)) / segments;
    final filled = fraction * segments;

    for (var i = 0; i < segments; i++) {
      final x = i * (segW + gap);
      final rect = Rect.fromLTWH(x, 0, segW, size.height);

      // How much of *this* segment is filled, so the bar moves smoothly.
      final amount = (filled - i).clamp(0.0, 1.0);

      canvas.drawRect(rect, Paint()..color = Hue.steelDim);
      if (amount > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, segW * amount, size.height),
          Paint()..color = color,
        );
      }
    }

    // A brighter cap on the leading edge, like a charged meter.
    if (fraction > 0 && fraction < 1) {
      final lead = math.min(filled.floor(), segments - 1);
      final x = lead * (segW + gap);
      canvas.drawRect(
        Rect.fromLTWH(x, 0, segW * (filled - lead).clamp(0.0, 1.0), size.height),
        Paint()..color = Color.lerp(color, Colors.white, 0.35)!,
      );
    }
  }

  @override
  bool shouldRepaint(_SegmentPainter old) =>
      old.fraction != fraction || old.color != color || old.segments != segments;
}
