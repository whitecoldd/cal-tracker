import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// One selectable option.
class Choice<T> {
  const Choice({required this.value, required this.title, this.blurb});

  final T value;
  final String title;

  /// Plain-language explanation under the title.
  ///
  /// The lore names are flavour; the blurb is what actually tells the user
  /// which option describes them, so it is never decoration.
  final String? blurb;
}

/// A vertical list of ornate, selectable rows.
///
/// Used wherever the user picks one of a handful of named options — sex,
/// activity level, goal, the day the week closes.
class ChoiceList<T> extends StatelessWidget {
  const ChoiceList({
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.accent = Hue.gold,
    super.key,
  });

  final List<Choice<T>> choices;
  final T? selected;
  final ValueChanged<T> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final choice in choices) ...[
          _ChoiceRow<T>(
            choice: choice,
            isSelected: choice.value == selected,
            accent: accent,
            onTap: () => onSelected(choice.value),
          ),
          if (choice != choices.last) const SizedBox(height: Space.sm),
        ],
      ],
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.choice,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  final Choice<T> choice;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: CustomPaint(
          painter: _RowPainter(isSelected: isSelected, accent: accent),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.md,
              vertical: Space.md,
            ),
            child: Row(
              children: [
                _Marker(isSelected: isSelected, accent: accent),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        choice.title,
                        style: Type.prose(
                          size: 15,
                          weight: isSelected ? 600 : 400,
                          color: isSelected ? Hue.parchment : Hue.parchmentDim,
                        ),
                      ),
                      if (choice.blurb != null) ...[
                        const SizedBox(height: Space.xxs),
                        Text(choice.blurb!, style: Type.lore(size: 12)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A diamond that fills when its row is chosen.
class _Marker extends StatelessWidget {
  const _Marker({required this.isSelected, required this.accent});

  final bool isSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(
        painter: _DiamondPainter(isSelected: isSelected, accent: accent),
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  const _DiamondPainter({required this.isSelected, required this.accent});

  final bool isSelected;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    Path diamond(double radius) => Path()
      ..moveTo(c.dx, c.dy - radius)
      ..lineTo(c.dx + radius, c.dy)
      ..lineTo(c.dx, c.dy + radius)
      ..lineTo(c.dx - radius, c.dy)
      ..close();

    canvas.drawPath(
      diamond(r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = isSelected ? accent : Hue.steel,
    );

    if (isSelected) {
      canvas.drawPath(diamond(r * 0.5), Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(_DiamondPainter old) =>
      old.isSelected != isSelected || old.accent != accent;
}

class _RowPainter extends CustomPainter {
  const _RowPainter({required this.isSelected, required this.accent});

  final bool isSelected;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()..color = isSelected ? Hue.surfaceRaised : Hue.surface,
    );

    if (isSelected) {
      // A lit edge on the left, like a selected entry in a game menu.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 2.5, size.height),
        Paint()..color = accent,
      );
    }

    canvas.drawRect(
      rect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = isSelected ? accent.withValues(alpha: 0.55) : Hue.steelDim,
    );
  }

  @override
  bool shouldRepaint(_RowPainter old) =>
      old.isSelected != isSelected || old.accent != accent;
}
