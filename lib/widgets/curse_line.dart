import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// One harm reading: what it is, what it measured, and what it is measured
/// against.
///
/// This row existed twice before T39 — `_Curse` on Alchemy and `_Weakness` on
/// the creature sheet, byte for byte — and the weekly report needed a third.
/// Three copies is where a shape stops being a coincidence.
///
/// A harm surface never shows one of these alone: the panel that holds them
/// carries `harmDisclaimer`, per CLAUDE.md §7.
class CurseLine extends StatelessWidget {
  const CurseLine({
    required this.title,
    required this.detail,
    required this.basis,
    required this.isPastGuideline,
    this.trailing,
    super.key,
  });

  /// The in-world name — `HarmKind.title`.
  final String title;

  /// The measured figure, in words.
  final String detail;

  /// The public guideline it is measured against, so the line is never a bare
  /// accusation.
  final String basis;

  /// Whether the reading reached or passed the guideline.
  final bool isPastGuideline;

  /// Optional extra beneath the basis — the weekly report puts the foods that
  /// carried it here.
  final Widget? trailing;

  /// Past the guideline reads red; under it stays parchment.
  ///
  /// Not steel, which rendered dimmer than the detail beside it and inverted
  /// the hierarchy — the name of the curse has to lead. And not bloodRed,
  /// which T1 already found unreadable as text on this ground.
  Color get _colour => isPastGuideline ? Hue.vitality : Hue.parchmentDim;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Both sides shrink: a harm detail can be as long as
              // "60 g — 24% of energy", and a fixed side would overflow the
              // row on a narrow phone.
              Flexible(
                flex: 4,
                child: Text(title.toUpperCase(), style: Type.label(color: _colour)),
              ),
              const SizedBox(width: Space.sm),
              Flexible(
                flex: 5,
                child: Text(
                  detail,
                  textAlign: TextAlign.right,
                  style: Type.prose(size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xxs),
          // The guideline itself, so a flag is never a bare accusation.
          Text(basis, style: Type.lore(size: 11)),
          if (trailing != null) ...[
            const SizedBox(height: Space.xs),
            trailing!,
          ],
        ],
      ),
    );
  }
}
