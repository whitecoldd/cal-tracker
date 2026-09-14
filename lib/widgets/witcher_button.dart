import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Weight of a button in the hierarchy.
enum ButtonTone {
  /// Gold, filled. One per screen at most.
  primary,

  /// Outlined steel. The default.
  secondary,

  /// Red outline. Destructive or harmful.
  danger,
}

/// A flat, bevelled button with clipped corners — no rounded pills anywhere.
class WitcherButton extends StatelessWidget {
  const WitcherButton({
    required this.label,
    required this.onPressed,
    this.tone = ButtonTone.secondary,
    this.icon,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonTone tone;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (Color border, Color fill, Color text) = switch (tone) {
      ButtonTone.primary => (Hue.gold, Hue.gold, Hue.voidBlack),
      ButtonTone.secondary => (Hue.steel, Colors.transparent, Hue.parchment),
      ButtonTone.danger => (Hue.bloodRed, Colors.transparent, Hue.vitality),
    };

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.md,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: enabled ? text : Hue.parchmentFaint),
            const SizedBox(width: Space.sm),
          ],
          Text(
            label.toUpperCase(),
            style: Type.label(
              size: 12,
              color: enabled ? text : Hue.parchmentFaint,
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: ClipPath(
        clipper: const _BevelClipper(),
        child: Material(
          color: fill,
          child: InkWell(
            onTap: onPressed,
            child: CustomPaint(
              painter: _BevelBorderPainter(border),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

const double _bevel = 7;

Path _bevelPath(Size size) {
  final w = size.width;
  final h = size.height;
  return Path()
    ..moveTo(_bevel, 0)
    ..lineTo(w - _bevel, 0)
    ..lineTo(w, _bevel)
    ..lineTo(w, h - _bevel)
    ..lineTo(w - _bevel, h)
    ..lineTo(_bevel, h)
    ..lineTo(0, h - _bevel)
    ..lineTo(0, _bevel)
    ..close();
}

class _BevelClipper extends CustomClipper<Path> {
  const _BevelClipper();

  @override
  Path getClip(Size size) => _bevelPath(size);

  @override
  bool shouldReclip(_BevelClipper oldClipper) => false;
}

class _BevelBorderPainter extends CustomPainter {
  const _BevelBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _bevelPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_BevelBorderPainter old) => old.color != color;
}
