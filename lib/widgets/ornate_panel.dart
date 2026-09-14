import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A bordered panel with engraved corner brackets — the base container of the
/// whole app.
///
/// The brackets are drawn rather than imaged so they stay crisp at any size and
/// can be tinted per state (gold when active, steel at rest, red when harmful).
class OrnatePanel extends StatelessWidget {
  const OrnatePanel({
    required this.child,
    this.title,
    this.trailing,
    this.accent = Hue.steel,
    this.background = Hue.surface,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    super.key,
  });

  final Widget child;

  /// Optional engraved header, upper-cased by the panel.
  final String? title;

  /// Optional widget pinned to the right of the header.
  final Widget? trailing;

  /// Colour of the frame and brackets.
  final Color accent;

  final Color background;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Header colour.
  ///
  /// A steel frame gets ordinary dimmed text. A coloured frame tints the header
  /// to match — but the darkest accents (blood red) are lifted towards parchment
  /// first, because at full strength they are unreadable on the panel fill.
  Color get _titleColor {
    if (accent == Hue.steel) return Hue.parchmentDim;
    if (accent.computeLuminance() < 0.12) {
      return Color.lerp(accent, Hue.parchment, 0.45)!;
    }
    return accent;
  }

  @override
  Widget build(BuildContext context) {
    final Widget panel = CustomPaint(
      painter: _FramePainter(accent: accent, background: background),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: Type.label(color: _titleColor),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: Space.md),
            ],
            child,
          ],
        ),
      ),
    );

    if (onTap == null) return panel;
    return InkWell(onTap: onTap, child: panel);
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.accent, required this.background});

  final Color accent;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Fill: a faint top-down gradient so panels read as lit from above.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(background, Colors.white, 0.03)!,
            background,
          ],
        ).createShader(rect),
    );

    // Hairline frame, dimmer than the brackets.
    canvas.drawRect(
      rect.deflate(Geometry.frameStroke / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Geometry.frameStroke
        ..color = accent.withValues(alpha: 0.35),
    );

    // Corner brackets: two arms per corner, full strength.
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Geometry.frameStroke + 0.4
      ..strokeCap = StrokeCap.square
      ..color = accent;

    const a = Geometry.bracketArm;
    const i = Geometry.frameStroke / 2;
    final w = size.width;
    final h = size.height;

    void corner(double x, double y, double dx, double dy) {
      canvas
        ..drawLine(Offset(x, y), Offset(x + a * dx, y), bracket)
        ..drawLine(Offset(x, y), Offset(x, y + a * dy), bracket);
    }

    corner(i, i, 1, 1); // top-left
    corner(w - i, i, -1, 1); // top-right
    corner(i, h - i, 1, -1); // bottom-left
    corner(w - i, h - i, -1, -1); // bottom-right
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.accent != accent || old.background != background;
}
