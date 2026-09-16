import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/daos/journal_dao.dart';
import '../../data/nutrition_adapter.dart';
import '../../domain/harm.dart';
import '../../domain/nutrition.dart';
import '../../domain/scoring.dart';
import '../../providers/app_providers.dart';
import '../journal/journal_providers.dart';
import '../path/mutagen_providers.dart';

/// The day's nutrient rollup.
final alchemyTotalsProvider = Provider<NutrientTotals>(
  (ref) => ref.watch(dailyTotalsProvider).nutrients,
);

/// The day's macro composition, for the vials.
final macroSharesProvider = Provider<List<MacroShare>>(
  (ref) => macroShares(ref.watch(alchemyTotalsProvider)),
);

/// The day's harm readings.
final toxinsProvider = Provider<Toxins>(
  (ref) => readToxins(ref.watch(alchemyTotalsProvider)),
);

/// Diet quality, 0..100.
///
/// Reads the latest weigh-in for protein adequacy. That is safe: weight is
/// logged and shown every day, and only its *interpretation* is sealed
/// (CLAUDE.md §1). Nothing here touches TDEE or a weight trend.
final vitalityProvider = Provider<Vitality>((ref) {
  final weight = ref.watch(latestWeightProvider).valueOrNull;
  return scoreVitality(ref.watch(alchemyTotalsProvider), bodyMassKg: weight);
});

/// Accumulated toxicity, including what has carried over from previous days.
///
/// Folds a bounded window of daily loads rather than recursing through all of
/// history — past about a week the retained fraction is below what the meter
/// can show. See [Toxicity.window].
final toxicityProvider = FutureProvider<double>((ref) async {
  final day = ref.watch(journalDayProvider);

  // Re-read when today's log changes, so the meter moves as food is added.
  ref.watch(journalEntriesProvider);

  final db = ref.watch(databaseProvider);
  final from = day.addDays(-Toxicity.lookbackDays);
  final items = await db.journalDao.forRange(from, day);

  final byDay = items.groupListsBy((i) => i.entry.day);

  // Every day in the window, including the ones with nothing logged: a gap is
  // a day of decay, and skipping it would let toxicity survive untouched
  // across a week of not eating anything notable.
  final loads = [
    for (var i = 0; i <= Toxicity.lookbackDays; i++)
      _loadOn(byDay[from.addDays(i)]),
  ];

  // The perk in force on *that* day, not today's: paging back to an old day
  // should show the carry-over it actually had.
  final bonus = await ref.watch(bonusOnDayProvider(day).future);

  return Toxicity.across(
    loads,
    retention: Toxicity.retentionWith(bonus.purge),
  );
});

double _loadOn(List<LoggedItem>? items) {
  if (items == null || items.isEmpty) return 0;
  return readToxins(NutrientTotals.of(items.servings)).load;
}
