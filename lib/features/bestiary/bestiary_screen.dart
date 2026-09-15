import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/bestiary.dart';
import '../../domain/rarity.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/food_card.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/stat_bar.dart';
import 'bestiary_providers.dart';
import 'creature_sheet.dart';

/// The Bestiary — every food ever logged, as a collection.
///
/// Shows what has actually been *eaten* by default, not everything the library
/// knows: the seed table is there from the first launch, and a collection that
/// claimed 132 entries on day one would mean nothing.
class BestiaryScreen extends ConsumerStatefulWidget {
  const BestiaryScreen({super.key});

  @override
  ConsumerState<BestiaryScreen> createState() => _BestiaryScreenState();
}

class _BestiaryScreenState extends ConsumerState<BestiaryScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arranged = ref.watch(arrangedBestiaryProvider);

    return Column(
      children: [
        const _Progress(),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
          child: TextField(
            controller: _search,
            style: Type.prose(size: 14),
            cursorColor: Hue.gold,
            onChanged: ref.read(bestiaryQueryProvider.notifier).set,
            decoration: const InputDecoration(
              hintText: 'Search the bestiary',
              prefixIcon: Icon(Icons.search, color: Hue.parchmentDim),
            ),
          ),
        ),
        const _Controls(),
        Expanded(
          child: switch (arranged) {
            AsyncData(:final value) when value.isEmpty => const _Empty(),
            AsyncData(:final value) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.sm,
                  Space.lg,
                  Space.huge,
                ),
                itemCount: value.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (_, i) => _Entry(creature: value[i]),
              ),
            AsyncError(:final error) => Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Text('$error', style: Type.lore(size: 12)),
              ),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

/// How full the collection is, by tier.
class _Progress extends ConsumerWidget {
  const _Progress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(bestiaryProgressProvider);
    final creatures = ref.watch(creaturesProvider).valueOrNull ?? const [];
    final byTier = BestiaryProgress.byRarity(creatures);

    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: OrnatePanel(
        title: 'The collection',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatBar(
              label: 'Creatures found',
              value: progress.caught.toDouble(),
              max: progress.known.toDouble().clamp(1, double.infinity),
              color: Hue.gold,
              valueLabel: '${progress.caught} of ${progress.known} known',
            ),
            const SizedBox(height: Space.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final tier in FoodRarity.values)
                  Column(
                    children: [
                      Text(
                        '${byTier[tier] ?? 0}',
                        style: Type.numeral(size: 18, color: tier.color),
                      ),
                      Text(
                        tier.title.toUpperCase(),
                        style: Type.label(size: 9, color: tier.color),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ordering and the caught/all toggle.
class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(bestiaryOrderProvider);
    final filter = ref.watch(bestiaryFilterProvider);

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        children: [
          for (final option in BestiaryFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: ChoiceChip(
                label: Text(
                  option.label.toUpperCase(),
                  style: Type.label(
                    size: 9,
                    color:
                        option == filter ? Hue.voidBlack : Hue.parchmentDim,
                  ),
                ),
                selected: option == filter,
                selectedColor: Hue.gold,
                backgroundColor: Hue.surfaceRaised,
                onSelected: (_) =>
                    ref.read(bestiaryFilterProvider.notifier).set(option),
              ),
            ),
          const SizedBox(width: Space.md),
          for (final option in BestiaryOrder.values)
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: ChoiceChip(
                label: Text(
                  option.label.toUpperCase(),
                  style: Type.label(
                    size: 9,
                    color: option == order ? Hue.voidBlack : Hue.parchmentDim,
                  ),
                ),
                selected: option == order,
                selectedColor: Hue.steelLight,
                backgroundColor: Hue.surfaceRaised,
                onSelected: (_) =>
                    ref.read(bestiaryOrderProvider.notifier).set(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.creature});

  final Creature creature;

  @override
  Widget build(BuildContext context) {
    final card = FoodCard(
      name: creature.name,
      brand: creature.brand,
      rarity: creature.rarity,
      kcal: creature.panel.kcal.round(),
      detail: creature.isCaught
          ? 'Eaten ${creature.timesEaten} '
              '${creature.timesEaten == 1 ? "time" : "times"}'
          : 'Never eaten',
      toxicity: creature.toxicity,
      onTap: () => CreatureSheet.show(context, creature: creature),
    );

    // A food in the library but never eaten is a rumour, not a sighting.
    return creature.isCaught ? card : Opacity(opacity: 0.45, child: card);
  }
}

class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(bestiaryFilterProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Text(
          filter == BestiaryFilter.caught
              ? 'Nothing caught yet. Log a meal and its parts appear here.'
              : 'Nothing by that name in the library.',
          textAlign: TextAlign.center,
          style: Type.lore(),
        ),
      ),
    );
  }
}
