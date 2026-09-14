import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The five Signs. Each maps to a real behaviour — see the vault's
/// `03-Game-Design` note.
enum Sign {
  /// Protein adequacy / thermic effect.
  igni('Igni', 'Protein & burn'),

  /// Fibre and micronutrient coverage.
  quen('Quen', 'Fibre & shield'),

  /// Activity — steps and distance.
  aard('Aard', 'Force & motion'),

  /// Consistency — logging streak and glycemic stability.
  axii('Axii', 'Control & calm'),

  /// Hydration and meal-timing discipline.
  yrden('Yrden', 'Water & timing');

  const Sign(this.title, this.blurb);

  final String title;
  final String blurb;
}

/// A Sign rune drawn inside its circle, dimmed when the buff is inactive.
///
/// The runes are drawn geometry rather than glyphs from a font so they stay
/// sharp at any size and can be charged (0..1) to show partial progress.
class SignGlyph extends StatelessWidget {
  const SignGlyph({
    required this.sign,
    this.charge = 1.0,
    this.size = 44,
    this.showLabel = false,
    super.key,
  });

  final Sign sign;

  /// 0 = dormant, 1 = fully active. Drives both colour and the ring sweep.
  final double charge;

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final glyph = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SignPainter(sign: sign, charge: charge.clamp(0.0, 1.0)),
      ),
    );

    if (!showLabel) return glyph;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph,
        const SizedBox(height: Space.sm),
        Text(
          sign.title.toUpperCase(),
          style: Type.label(
            color: charge > 0.5 ? Hue.gold : Hue.parchmentFaint,
          ),
        ),
      ],
    );
  }
}

/// An Archimedean spiral of [turns] revolutions, drawn through [p] so it lands
/// in the same -1..1 authoring box as the other runes.
Path _spiral(Offset Function(double, double) p, {double turns = 1.75}) {
  final path = Path();
  const steps = 72;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final angle = t * turns * 2 * math.pi;
    final radius = t; // grows linearly with the sweep
    final o = p(radius * math.cos(angle), radius * math.sin(angle));
    if (i == 0) {
      path.moveTo(o.dx, o.dy);
    } else {
      path.lineTo(o.dx, o.dy);
    }
  }
  return path;
}

class _SignPainter extends CustomPainter {
  const _SignPainter({required this.sign, required this.charge});

  final Sign sign;
  final double charge;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final active = Color.lerp(Hue.steel, Hue.gold, charge)!;

    // Dormant ring.
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Hue.steelDim,
    );

    // Charge sweep, clockwise from the top.
    if (charge > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 1),
        -math.pi / 2,
        2 * math.pi * charge,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = Hue.gold,
      );
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, r * 0.09)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = active;

    // Runes are authored in a -1..1 box and scaled to the inner circle.
    final u = r * 0.52;
    Offset p(double x, double y) => Offset(c.dx + x * u, c.dy + y * u);

    final path = switch (sign) {
      // Aard: a downward trident — force pushed outward.
      Sign.aard => Path()
        ..moveTo(p(0, -1).dx, p(0, -1).dy)
        ..lineTo(p(0, 1).dx, p(0, 1).dy)
        ..moveTo(p(-0.85, -0.15).dx, p(-0.85, -0.15).dy)
        ..lineTo(p(0, 0.7).dx, p(0, 0.7).dy)
        ..lineTo(p(0.85, -0.15).dx, p(0.85, -0.15).dy),

      // Igni: a flame — an outer tongue with a smaller one curling inside.
      Sign.igni => Path()
        ..moveTo(p(-0.62, 0.92).dx, p(-0.62, 0.92).dy)
        ..cubicTo(
          p(-1.05, -0.05).dx, p(-1.05, -0.05).dy,
          p(-0.3, -0.35).dx, p(-0.3, -0.35).dy,
          p(0.02, -1).dx, p(0.02, -1).dy,
        )
        ..cubicTo(
          p(0.35, -0.3).dx, p(0.35, -0.3).dy,
          p(1.05, -0.05).dx, p(1.05, -0.05).dy,
          p(0.62, 0.92).dx, p(0.62, 0.92).dy,
        )
        ..moveTo(p(-0.24, 0.92).dx, p(-0.24, 0.92).dy)
        ..cubicTo(
          p(-0.5, 0.28).dx, p(-0.5, 0.28).dy,
          p(0.1, 0.12).dx, p(0.1, 0.12).dy,
          p(0.06, -0.34).dx, p(0.06, -0.34).dy,
        ),

      // Quen: a dome over a stem — the shield.
      Sign.quen => Path()
        ..moveTo(p(-0.85, 0.45).dx, p(-0.85, 0.45).dy)
        ..quadraticBezierTo(
          p(0, -1.35).dx, p(0, -1.35).dy,
          p(0.85, 0.45).dx, p(0.85, 0.45).dy,
        )
        ..moveTo(p(0, 1).dx, p(0, 1).dy)
        ..lineTo(p(0, -0.35).dx, p(0, -0.35).dy),

      // Axii: a spiral winding inwards — a mind drawn under.
      Sign.axii => _spiral(p),

      // Yrden: a warded diamond — the trap laid on the ground.
      Sign.yrden => Path()
        ..moveTo(p(0, -1).dx, p(0, -1).dy)
        ..lineTo(p(0.95, 0).dx, p(0.95, 0).dy)
        ..lineTo(p(0, 1).dx, p(0, 1).dy)
        ..lineTo(p(-0.95, 0).dx, p(-0.95, 0).dy)
        ..close()
        ..moveTo(p(0, -0.42).dx, p(0, -0.42).dy)
        ..lineTo(p(0, 0.42).dx, p(0, 0.42).dy)
        ..moveTo(p(-0.4, 0).dx, p(-0.4, 0).dy)
        ..lineTo(p(0.4, 0).dx, p(0.4, 0).dy),
    };

    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_SignPainter old) =>
      old.sign != sign || old.charge != charge;
}
