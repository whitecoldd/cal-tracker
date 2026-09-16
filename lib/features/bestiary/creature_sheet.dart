import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/bestiary.dart';
import '../../domain/harm.dart';
import '../../domain/nutrition.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/creature_plate.dart';
import '../../widgets/food_card.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import 'bestiary_providers.dart';

/// One creature's full entry.
///
/// A harm surface, so it carries the standing disclaimer — *lore, not a
/// physician* — and every weakness states the public guideline it is measured
/// against rather than asserting a bare accusation. See CLAUDE.md §7.
class CreatureSheet extends StatelessWidget {
  const CreatureSheet({required this.creature, super.key});

  final Creature creature;

  static Future<void> show(
    BuildContext context, {
    required Creature creature,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatureSheet(creature: creature),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panel = creature.panel;

    return Padding(
      padding: const EdgeInsets.only(top: Space.huge),
      child: ColoredBox(
        color: Hue.voidBlack,
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          shrinkWrap: true,
          children: [
            _Header(creature: creature),
            const SizedBox(height: Space.lg),
            _Stats(panel: panel),
            const SizedBox(height: Space.lg),
            _Weaknesses(creature: creature),
            const SizedBox(height: Space.xl),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.creature});

  final Creature creature;

  @override
  Widget build(BuildContext context) {
    final first = creature.firstSeen;

    return OrnatePanel(
      title: creature.rarity.title,
      accent: creature.rarity.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Plate(creature: creature),
          Text(creature.name, style: Type.heading(size: 20)),
          if (creature.brand != null)
            Text(creature.brand!, style: Type.lore(size: 12)),
          const RunicDivider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  creature.isCaught
                      ? 'Eaten ${creature.timesEaten} '
                          '${creature.timesEaten == 1 ? "time" : "times"}'
                      : 'Known, never eaten',
                  style: Type.prose(size: 13),
                ),
              ),
              if (first != null)
                Text(
                  'First ${DateFormat('d MMM yyyy').format(first.toDateTime())}',
                  style: Type.lore(size: 11, color: Hue.parchmentFaint),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The creature's picture, if Open Food Facts had one and it could be had.
///
/// Silent in every direction: no spinner while it is fetched, no message when
/// there is nothing to fetch, nothing at all when the network is gone. The
/// sheet is about the food, and a picture that cannot be shown is not news.
///
/// It sits above the name rather than beside it because T12b's note that "the
/// card has no room for it as drawn" was about the list row, and still is —
/// this is the sheet, which has the width.
class _Plate extends ConsumerWidget {
  const _Plate({required this.creature});

  final Creature creature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref
        .watch(creaturePlateProvider((
          id: creature.id,
          url: creature.imagePath,
        )))
        .valueOrNull;

    if (image == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: CreaturePlate(image: image, accent: creature.rarity.color),
    );
  }
}

/// The creature's stats, per 100 g.
class _Stats extends StatelessWidget {
  const _Stats({required this.panel});

  final FoodPanel panel;

  @override
  Widget build(BuildContext context) {
    final gi = panel.glycemicIndex;
    final nova = panel.novaGroup;

    return OrnatePanel(
      title: 'Stats',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Per 100 g',
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
          const SizedBox(height: Space.sm),
          _Stat(label: 'Energy', value: '${panel.kcal.round()} kcal'),
          _Stat(label: 'Protein', value: '${panel.proteinG.round()} g'),
          _Stat(label: 'Carbohydrate', value: '${panel.carbsG.round()} g'),
          _Stat(label: 'of which sugars', value: '${panel.sugarG.round()} g'),
          _Stat(label: 'Fat', value: '${panel.fatG.round()} g'),
          _Stat(label: 'of which saturated', value: '${panel.satFatG.round()} g'),
          _Stat(label: 'Fibre', value: '${panel.fibreG.round()} g'),
          _Stat(label: 'Sodium', value: '${panel.sodiumMg.round()} mg'),
          const RunicDivider(),
          _Stat(
            label: 'Glycemic index',
            // Unknown is stated, not guessed at — a food with too little
            // carbohydrate for the measure has no GI, which is not zero.
            value: gi == null ? 'Unknown' : '$gi',
          ),
          _Stat(
            label: 'Processing',
            value: nova == null ? 'Unknown' : 'NOVA $nova',
          ),
          if (panel.additiveCount > 0)
            _Stat(
              label: 'Additives',
              value: '${panel.additiveCount} listed',
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: Row(
        children: [
          Expanded(child: Text(label.toUpperCase(), style: Type.label())),
          const SizedBox(width: Space.sm),
          Text(value, style: Type.prose(size: 13)),
        ],
      ),
    );
  }
}

/// What this creature does to you — as lore, never as a diagnosis.
class _Weaknesses extends StatelessWidget {
  const _Weaknesses({required this.creature});

  final Creature creature;

  @override
  Widget build(BuildContext context) {
    final weaknesses = creature.weaknesses;

    return OrnatePanel(
      title: 'Weaknesses',
      accent: Hue.bloodRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (weaknesses.isEmpty)
            Text(
              'Nothing of note in this one.',
              style: Type.lore(),
            )
          else
            for (final flag in weaknesses) _Weakness(flag: flag),
          const RunicDivider(),
          // Required on every harm surface. See CLAUDE.md §7.
          Text(
            harmDisclaimer,
            style: Type.lore(size: 11, color: Hue.parchmentFaint),
          ),
        ],
      ),
    );
  }
}

class _Weakness extends StatelessWidget {
  const _Weakness({required this.flag});

  final HarmFlag flag;

  Color get _colour => flag.severity >= 1 ? Hue.vitality : Hue.parchmentDim;

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
              Flexible(
                flex: 4,
                child: Text(
                  flag.kind.title.toUpperCase(),
                  style: Type.label(color: _colour),
                ),
              ),
              const SizedBox(width: Space.sm),
              Flexible(
                flex: 5,
                child: Text(
                  flag.detail,
                  textAlign: TextAlign.right,
                  style: Type.prose(size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xxs),
          // The guideline itself, so a flag is never a bare accusation.
          Text(flag.kind.basis, style: Type.lore(size: 11)),
        ],
      ),
    );
  }
}
