import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/daos/journal_dao.dart';
import '../../data/tables.dart';
import '../../domain/day.dart';
import '../../domain/portion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/ornate_panel.dart';
import '../../widgets/runic_divider.dart';
import '../activity/activity_panel.dart';
import '../shell/paths_drawer.dart';
import 'food_search_sheet.dart';
import 'journal_providers.dart';
import 'portion_sheet.dart';

/// Today, as a quest log.
///
/// Shows what was eaten and what it was made of, and nothing about whether that
/// is good or bad. There is no target, no ring, no remaining-calories figure —
/// the verdict waits for the week to close. See CLAUDE.md §1.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(journalDayProvider);
    final view = ref.watch(journalDayViewProvider);
    final totals = ref.watch(dailyTotalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      drawer: const PathsDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Hue.gold,
        foregroundColor: Hue.voidBlack,
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        icon: const Icon(Icons.add, size: 18),
        label: Text('LOG', style: Type.label(size: 12, color: Hue.voidBlack)),
        onPressed: () => FoodSearchSheet.show(context, day: day),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _DayBar(day: day),
            Expanded(
              child: switch (view) {
                AsyncData(:final value) => _Body(day: value, totals: totals),
                AsyncError(:final error) => _Failed(error: error),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Date header with a way back through the week.
class _DayBar extends ConsumerWidget {
  const _DayBar({required this.day});

  final Day day;

  String get _label {
    final today = Day.today();
    if (day == today) return 'Today';
    if (day == today.addDays(-1)) return 'Yesterday';
    return DateFormat('EEEE d MMMM').format(day.toDateTime());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(journalDayProvider.notifier);
    final canGoForward = day.isBefore(Day.today());

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.sm),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => notifier.shift(-1),
            tooltip: 'Previous day',
          ),
          Expanded(
            child: GestureDetector(
              onTap: notifier.today,
              child: Column(
                children: [
                  Text(
                    _label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Type.heading(size: 15, letterSpacing: 2.4),
                  ),
                  Text(
                    DateFormat('d MMMM yyyy').format(day.toDateTime()),
                    style: Type.lore(size: 11, color: Hue.parchmentFaint),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            // The Journal never shows the future: there is nothing to log
            // there, and an empty tomorrow reads like data loss.
            onPressed: canGoForward ? () => notifier.shift(1) : null,
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.day, required this.totals});

  final JournalDay day;
  final DailyTotals totals;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 96),
      children: [
        _TotalsPanel(totals: totals),
        const SizedBox(height: Space.md),
        const ActivityPanel(),
        const SizedBox(height: Space.lg),
        if (day.isEmpty)
          const _EmptyDay()
        else
          for (final slot in MealSlot.values)
            if (day.byMeal[slot]!.isNotEmpty) ...[
              _MealSection(day: day.day, slot: slot, items: day.byMeal[slot]!),
              const SizedBox(height: Space.md),
            ],
      ],
    );
  }
}

/// What the day added up to.
///
/// Absolute figures only. Adding a target here would turn the Journal into a
/// scoreboard, which is the whole thing this app refuses to be.
class _TotalsPanel extends StatelessWidget {
  const _TotalsPanel({required this.totals});

  final DailyTotals totals;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      title: 'Taken in',
      trailing: totals.itemCount == 0
          ? null
          : Text(
              '${totals.itemCount} '
              '${totals.itemCount == 1 ? "entry" : "entries"}',
              style: Type.label(size: 9),
            ),
      child: Column(
        children: [
          Text(
            totals.kcal.round().toString(),
            style: Type.numeral(size: 40, color: Hue.parchment),
          ),
          Text('KCAL', style: Type.label(size: 9)),
          const RunicDivider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Macro(label: 'Protein', grams: totals.proteinG, color: Hue.vitality),
              _Macro(label: 'Carbs', grams: totals.carbsG, color: Hue.stamina),
              _Macro(label: 'Fat', grams: totals.fatG, color: Hue.adrenaline),
              _Macro(label: 'Fibre', grams: totals.fibreG, color: Hue.toxicity),
            ],
          ),
          if (totals.lowConfidenceCount > 0) ...[
            const SizedBox(height: Space.md),
            Row(
              children: [
                const Icon(Icons.help_outline, size: 13, color: Hue.adrenaline),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    totals.lowConfidenceCount == 1
                        ? 'One of these rests on a rough portion. Tap it to '
                            'weigh it properly.'
                        : '${totals.lowConfidenceCount} of these rest on a '
                            'rough portion. Tap one to weigh it properly.',
                    style: Type.lore(size: 11, color: Hue.adrenaline),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.grams, required this.color});

  final String label;
  final double grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${grams.round()}g',
          style: Type.prose(size: 16, weight: 600, color: color),
        ),
        const SizedBox(height: Space.xxs),
        Text(label.toUpperCase(), style: Type.label(size: 9)),
      ],
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.day,
    required this.slot,
    required this.items,
  });

  final Day day;
  final MealSlot slot;
  final List<LoggedItem> items;

  static const _names = {
    MealSlot.breakfast: 'Breakfast',
    MealSlot.lunch: 'Lunch',
    MealSlot.dinner: 'Dinner',
    MealSlot.snack: 'Snacks',
  };

  @override
  Widget build(BuildContext context) {
    final kcal = items.fold<double>(0, (sum, i) => sum + i.kcal);

    return OrnatePanel(
      title: _names[slot]!,
      trailing: Text('${kcal.round()} kcal', style: Type.label(size: 10)),
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
      child: Column(
        children: [
          for (final item in items)
            _EntryRow(
              day: day,
              item: item,
              isLast: item == items.last,
            ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.day,
    required this.item,
    required this.isLast,
  });

  final Day day;
  final LoggedItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final portion = describePortion(
      quantity: item.entry.quantity,
      unit: item.entry.unit,
      pieceName: item.food.pieceName,
    );
    final vague = item.entry.confidence < 0.7;

    return Column(
      children: [
        InkWell(
          onTap: () => PortionSheet.show(
            context,
            food: item.food,
            day: day,
            existing: item.entry,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.food.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.prose(size: 14),
                      ),
                      const SizedBox(height: Space.xxs),
                      Row(
                        children: [
                          Text(
                            portion,
                            style: Type.lore(size: 11),
                          ),
                          if (vague) ...[
                            const SizedBox(width: Space.xs),
                            const Icon(
                              Icons.help_outline,
                              size: 11,
                              color: Hue.adrenaline,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.sm),
                Text(
                  '${item.kcal.round()}',
                  style: Type.prose(size: 15, weight: 600),
                ),
                const SizedBox(width: Space.xs),
                Text('kcal', style: Type.label(size: 8)),
              ],
            ),
          ),
        ),
        if (!isLast)
          Container(height: 1, color: Hue.steelDim),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xl),
        child: Column(
          children: [
            Text(
              'The page is blank.',
              style: Type.heading(size: 16, color: Hue.parchmentDim),
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Nothing logged for this day yet.',
              style: Type.lore(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: OrnatePanel(
        title: 'The journal is unreadable',
        accent: Hue.bloodRed,
        child: Text('$error', style: Type.lore(size: 12)),
      ),
    );
  }
}
