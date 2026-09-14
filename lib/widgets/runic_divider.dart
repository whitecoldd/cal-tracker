import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A hairline rule that tapers away from a small centre diamond.
///
/// Used between sections inside a panel, where a plain [Divider] would read as
/// far too modern.
class RunicDivider extends StatelessWidget {
  const RunicDivider({this.color = Hue.steel, this.height = 18, super.key});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _DividerPainter(color)),
    );
  }
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final mid = size.width / 2;
    const gap = 9.0;

    // Lines fade out towards the centre diamond.
    final left = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0), color],
      ).createShader(Rect.fromLTWH(0, 0, mid - gap, 1))
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y), Offset(mid - gap, y), left);

    final right = Paint()
      ..shader = LinearGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(mid + gap, 0, mid - gap, 1))
      ..strokeWidth = 1;
    canvas.drawLine(Offset(mid + gap, y), Offset(size.width, y), right);

    // Centre diamond.
    final d = Path()
      ..moveTo(mid, y - 4)
      ..lineTo(mid + 4, y)
      ..lineTo(mid, y + 4)
      ..lineTo(mid - 4, y)
      ..close();
    canvas
      ..drawPath(d, Paint()..color = color)
      ..drawPath(
        d,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color,
      );
  }

  @override
  bool shouldRepaint(_DividerPainter old) => old.color != color;
}
