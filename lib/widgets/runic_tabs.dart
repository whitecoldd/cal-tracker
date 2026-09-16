import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// One segment of a [RunicTabs] strip.
class RunicTab<T> {
  const RunicTab({required this.value, required this.label, this.lore});

  final T value;

  /// Upper-cased by the widget — pass 'The Tally', not 'THE TALLY'.
  final String label;

  /// One line shown under the strip while this segment is chosen.
  ///
  /// The label is in-world and short; the lore is what actually tells the
  /// reader which of two readings they are about to get. Same division as
  /// [Choice.blurb].
  final String? lore;
}

/// A switch between two or three readings of the same thing.
///
/// Deliberately not a Material `TabBar`: there is no controller, no page view
/// and no sliding indicator. The caller owns the selection, exactly as
/// [ChoiceList] does, so the choice can live in a provider and a golden can be
/// taken of either state without driving an animation to settle first.
///
/// Nothing here animates. Engraved, not animated — and an implicit animation
/// would be one more thing `pumpAndSettle` has to outlive, which is the
/// lesson `_LevelUpMark` already carries from T21.
class RunicTabs<T> extends StatelessWidget {
  const RunicTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.accent = Hue.gold,
    super.key,
  });

  final List<RunicTab<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final chosen = tabs.where((t) => t.value == selected);
    final lore = chosen.isEmpty ? null : chosen.first.lore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 38,
          child: Row(
            children: [
              for (final tab in tabs)
                Expanded(
                  child: _Segment<T>(
                    tab: tab,
                    isSelected: tab.value == selected,
                    isFirst: tab == tabs.first,
                    accent: accent,
                    onTap: () => onSelected(tab.value),
                  ),
                ),
            ],
          ),
        ),
        if (lore != null) ...[
          const SizedBox(height: Space.sm),
          Text(
            lore,
            textAlign: TextAlign.center,
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
        ],
      ],
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.tab,
    required this.isSelected,
    required this.isFirst,
    required this.accent,
    required this.onTap,
  });

  final RunicTab<T> tab;
  final bool isSelected;
  final bool isFirst;
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
          painter: _SegmentPainter(
            isSelected: isSelected,
            isFirst: isFirst,
            accent: accent,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: Text(
                tab.label.toUpperCase(),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Type.label(
                  size: 11,
                  color: isSelected ? accent : Hue.parchmentFaint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentPainter extends CustomPainter {
  const _SegmentPainter({
    required this.isSelected,
    required this.isFirst,
    required this.accent,
  });

  final bool isSelected;
  final bool isFirst;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()..color = isSelected ? Hue.surfaceRaised : Hue.surface,
    );

    // The frame, drawn per segment so the strip has one continuous hairline.
    canvas.drawRect(
      rect.deflate(Geometry.frameStroke / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Geometry.frameStroke
        ..color = isSelected
            ? accent.withValues(alpha: 0.55)
            : Hue.steel.withValues(alpha: 0.35),
    );

    // A divider between segments, so two unselected ones do not read as one
    // wide button.
    if (!isFirst && !isSelected) {
      canvas.drawLine(
        Offset(0, size.height * 0.25),
        Offset(0, size.height * 0.75),
        Paint()
          ..strokeWidth = 1
          ..color = Hue.steelDim,
      );
    }

    if (!isSelected) return;

    // The lit edge, along the bottom — the same idiom as a selected
    // `_ChoiceRow`, turned through ninety degrees.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 2.5, size.width, 2.5),
      Paint()..color = accent,
    );

    // Short brackets on the two top corners, so the chosen segment reads as a
    // small panel lifted out of the strip rather than as a filled button.
    const arm = Geometry.bracketArm / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = Geometry.frameStroke
      ..color = accent;

    canvas
      ..drawPath(
        Path()
          ..moveTo(0, arm)
          ..lineTo(0, 0)
          ..lineTo(arm, 0),
        stroke,
      )
      ..drawPath(
        Path()
          ..moveTo(size.width - arm, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, arm),
        stroke,
      );
  }

  @override
  bool shouldRepaint(_SegmentPainter old) =>
      old.isSelected != isSelected ||
      old.isFirst != isFirst ||
      old.accent != accent;
}
