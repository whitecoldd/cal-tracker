import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A potion vial used to show one macro against its target.
///
/// Over-filling is meaningful — the liquid rises past the neck and the glass
/// takes the macro's colour, so "too much" looks different from "enough"
/// without needing a warning icon.
class AlchemyVial extends StatelessWidget {
  const AlchemyVial({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
    this.unit = 'g',
    this.width = 44,
    this.height = 92,
    super.key,
  });

  final String label;
  final double value;
  final double target;
  final Color color;
  final String unit;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fraction = target <= 0 ? 0.0 : value / target;
    final over = fraction > 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _VialPainter(
              fraction: fraction.clamp(0.0, 1.25),
              color: color,
              over: over,
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(label.toUpperCase(), style: Type.label()),
        const SizedBox(height: Space.xxs),
        Text(
          '${value.round()}$unit',
          style: Type.prose(
            size: 13,
            weight: 600,
            color: over ? Hue.adrenaline : Hue.parchment,
          ),
        ),
        Text(
          'of ${target.round()}$unit',
          style: Type.prose(size: 11, color: Hue.parchmentFaint),
        ),
      ],
    );
  }
}

class _VialPainter extends CustomPainter {
  const _VialPainter({
    required this.fraction,
    required this.color,
    required this.over,
  });

  final double fraction;
  final Color color;
  final bool over;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final neckW = w * 0.42;
    final neckH = h * 0.18;
    final bodyTop = neckH;

    // Flask silhouette: narrow neck, shoulders, rounded belly.
    final flask = Path()
      ..moveTo((w - neckW) / 2, 0)
      ..lineTo((w - neckW) / 2, bodyTop * 0.8)
      ..quadraticBezierTo(0, bodyTop * 1.15, 0, h * 0.55)
      ..arcToPoint(
        Offset(w, h * 0.55),
        radius: Radius.circular(w * 0.55),
        clockwise: false,
        largeArc: true,
      )
      ..quadraticBezierTo(w, bodyTop * 1.15, (w + neckW) / 2, bodyTop * 0.8)
      ..lineTo((w + neckW) / 2, 0)
      ..close();

    // Glass.
    canvas
      ..drawPath(flask, Paint()..color = Hue.voidBlack)
      ..save()
      ..clipPath(flask);

    // Liquid, filling from the bottom.
    final level = h * (1 - fraction.clamp(0.0, 1.0)) * 0.92;
    final liquid = Rect.fromLTRB(0, level, w, h);
    canvas.drawRect(
      liquid,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.22)!,
            color,
            Color.lerp(color, Colors.black, 0.35)!,
          ],
        ).createShader(liquid),
    );

    // Meniscus highlight.
    if (fraction > 0) {
      canvas.drawLine(
        Offset(0, level),
        Offset(w, level),
        Paint()
          ..color = Color.lerp(color, Colors.white, 0.55)!
          ..strokeWidth = 1.5,
      );
    }

    canvas.restore();

    // Outline. Takes the liquid's colour when over target.
    canvas.drawPath(
      flask,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = over ? Hue.adrenaline : Hue.steel,
    );

    // Cork.
    final cork = Rect.fromLTWH((w - neckW) / 2 - 2, -1, neckW + 4, 6);
    canvas.drawRect(cork, Paint()..color = Hue.steel);
  }

  @override
  bool shouldRepaint(_VialPainter old) =>
      old.fraction != fraction || old.color != color || old.over != over;
}
