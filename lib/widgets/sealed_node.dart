import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/sealed_value.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Renders a [SealedValue]: the number when revealed, a chained seal when not.
///
/// The seal is deliberately ornamental rather than an error state. A locked
/// panel should feel like part of the world — something waiting to open — not
/// like a feature that failed to load.
class SealedNode extends StatelessWidget {
  const SealedNode({
    required this.label,
    required this.value,
    this.format,
    this.lore = 'The medallion trembles, but the path is not yet clear.',
    this.accent = Hue.gold,
    super.key,
  });

  final String label;
  final SealedValue<num> value;

  /// How to render the revealed number. Defaults to a rounded integer.
  final String Function(num)? format;

  /// Flavour line shown while sealed.
  final String lore;

  final Color accent;

  static const double _bandHeight = 40;
  static const double _loreHeight = 32;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: Type.label(
            color: value.isRevealed ? Hue.parchmentDim : Hue.parchmentFaint,
          ),
        ),
        const SizedBox(height: Space.md),
        // The chained band and the revealed numeral share a height, so
        // unsealing does not make the panel jump.
        SizedBox(
          height: _bandHeight,
          child: switch (value) {
            // Scaled down rather than wrapped: the band has a fixed height so
            // that unsealing does not make the panel jump, and a value long
            // enough to wrap ("-3850 kcal") would be clipped by it instead.
            Revealed(value: final v) => Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    (format ?? (n) => n.round().toString())(v),
                    maxLines: 1,
                    softWrap: false,
                    style: Type.numeral(size: 28, color: accent),
                  ),
                ),
              ),
            Sealed() => const _ChainedBand(),
          },
        ),
        const SizedBox(height: Space.sm),
        SizedBox(
          height: _loreHeight,
          child: switch (value) {
            Revealed() => const SizedBox.shrink(),
            Sealed() => Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                child: Text(
                  lore,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Type.lore(size: 11, color: Hue.parchmentFaint),
                ),
              ),
          },
        ),
      ],
    );
  }
}

/// A chain running across the node with a wax seal set into the middle.
///
/// The chain is confined to its own band rather than crossing the whole node,
/// so it never runs through the label or the flavour line.
class _ChainedBand extends StatelessWidget {
  const _ChainedBand();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: CustomPaint(painter: _ChainPainter())),
        SizedBox(
          width: 34,
          height: 34,
          child: CustomPaint(painter: _SealPainter()),
        ),
      ],
    );
  }
}

/// The disc at the centre of the chain: a dark medallion with a keyhole.
class _SealPainter extends CustomPainter {
  const _SealPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    canvas
      // Solid ground so the chain never shows through the medallion.
      ..drawCircle(c, r, Paint()..color = Hue.voidBlack)
      ..drawCircle(
        c,
        r - 1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Hue.goldDim,
      )
      ..drawCircle(
        c,
        r - 4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Hue.steel,
      );

    // Keyhole: a small circle over a taper.
    final keyhole = Path()
      ..addOval(Rect.fromCircle(center: c.translate(0, -2.2), radius: 2.6))
      ..moveTo(c.dx - 2.4, c.dy + 6)
      ..lineTo(c.dx - 0.9, c.dy - 0.4)
      ..lineTo(c.dx + 0.9, c.dy - 0.4)
      ..lineTo(c.dx + 2.4, c.dy + 6)
      ..close();

    canvas.drawPath(keyhole, Paint()..color = Hue.goldDim);
  }

  @override
  bool shouldRepaint(_SealPainter oldDelegate) => false;
}

/// A horizontal chain with a faint hatch behind it.
class _ChainPainter extends CustomPainter {
  const _ChainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Faint diagonal hatch so the band reads as "covered".
    final hatch = Paint()
      ..color = Hue.steelDim.withValues(alpha: 0.85)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hatch);
    }

    // The chain runs level across the middle, tilted just enough to look slack.
    final y = size.height / 2;
    final start = Offset(-8, y + 3);
    final end = Offset(size.width + 8, y - 3);
    final delta = end - start;
    final angle = math.atan2(delta.dy, delta.dx);

    const linkLen = 15.0;
    const linkWide = 8.5;
    final count = (delta.distance / (linkLen * 0.72)).ceil();

    canvas
      ..save()
      ..translate(start.dx, start.dy)
      ..rotate(angle);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..color = Hue.steelLight;
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..color = Hue.voidBlack;

    for (var i = 0; i < count; i++) {
      // Alternate links turn edge-on, which is what makes it read as a chain.
      final wide = i.isEven;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(i * linkLen * 0.72, 0),
          width: linkLen,
          height: wide ? linkWide : linkWide * 0.42,
        ),
        Radius.circular(wide ? linkWide / 2 : linkWide * 0.21),
      );
      canvas
        ..drawRRect(rrect, shadow)
        ..drawRRect(rrect, stroke);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChainPainter oldDelegate) => false;
}
