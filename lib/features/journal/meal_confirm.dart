import 'package:flutter/material.dart';

import '../../data/ai/meal_resolver.dart';
import '../../data/tables.dart';
import '../../domain/portion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../../widgets/witcher_button.dart';

/// What the model read, before anything is written to the Journal.
///
/// Always shown, for both the typed and the photographed paths. A parse is a
/// guess, and a guess that logs itself is how a food diary quietly fills with
/// things nobody ate.
///
/// Shared between the two sheets rather than copied: the confirm step is the
/// only thing standing between a model's mistake and the day's totals, and two
/// copies of it would eventually disagree about what it shows.
class MealConfirm extends StatelessWidget {
  const MealConfirm({
    required this.items,
    required this.unrecognised,
    required this.slot,
    required this.onSlot,
    required this.onLog,
    required this.onDiscard,
    this.emptyMessage =
        'No food was recognised in that. Try naming the foods more plainly.',
    super.key,
  });

  final List<ResolvedItem> items;
  final List<String> unrecognised;
  final MealSlot slot;
  final ValueChanged<MealSlot> onSlot;
  final VoidCallback onLog;
  final VoidCallback onDiscard;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return OrnatePanel(
        title: 'Nothing found',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(emptyMessage, style: Type.lore()),
            const SizedBox(height: Space.md),
            WitcherButton(label: 'Start again', onPressed: onDiscard),
          ],
        ),
      );
    }

    return OrnatePanel(
      title: 'Read as',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items) _Row(item: item),
          if (unrecognised.isNotEmpty) ...[
            const RunicDivider(),
            Text('NOT UNDERSTOOD', style: Type.label(color: Hue.adrenaline)),
            const SizedBox(height: Space.xs),
            // Surfaced rather than dropped: a meal that logs three of four
            // things and says nothing about the fourth is the worse failure.
            for (final fragment in unrecognised)
              Text('· $fragment', style: Type.lore(size: 12)),
          ],
          const RunicDivider(),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final option in MealSlot.values)
                ChoiceChip(
                  label: Text(
                    option.name.toUpperCase(),
                    style: Type.label(
                      size: 10,
                      color: option == slot ? Hue.voidBlack : Hue.parchmentDim,
                    ),
                  ),
                  selected: option == slot,
                  selectedColor: Hue.gold,
                  backgroundColor: Hue.surfaceRaised,
                  onSelected: (_) => onSlot(option),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          WitcherButton(
            label: 'Write it down',
            tone: ButtonTone.primary,
            onPressed: onLog,
          ),
          const SizedBox(height: Space.sm),
          WitcherButton(label: 'Start again', onPressed: onDiscard),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});

  final ResolvedItem item;

  @override
  Widget build(BuildContext context) {
    final kcal = item.food.kcal * item.grams / 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.food.name, style: Type.prose(size: 14)),
                Text(
                  '${describePortion(
                    quantity: item.quantity,
                    unit: item.unit,
                    pieceName: item.food.pieceName,
                  )} · ${item.grams.round()}g · '
                  '${item.wasAlreadyKnown ? "from your library" : "read by the oracle"}',
                  style: Type.lore(
                    size: 11,
                    // The library's own figures and the model's deserve
                    // different levels of trust, so they do not look alike.
                    color:
                        item.wasAlreadyKnown ? Hue.parchmentDim : Hue.adrenaline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Text('${kcal.round()}', style: Type.numeral(size: 16)),
        ],
      ),
    );
  }
}
