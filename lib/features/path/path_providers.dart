import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/health/activity_sync.dart';
import '../../data/nutrition_adapter.dart';
import '../../domain/activity.dart';
import '../../domain/day.dart';
import '../../domain/nutrition.dart';
import '../../domain/progression.dart';
import '../../domain/scoring.dart';
import '../../domain/sealed_value.dart';
import '../../domain/signs.dart';
import '../../providers/app_providers.dart';
import '../activity/activity_providers.dart';
import '../journal/journal_providers.dart';
import '../reckoning/reckoning_providers.dart';

/// Every XP the user has ever been awarded.
///
/// Read from the sealed weeks rather than kept as a running total, so it can
/// never drift from the history it is supposed to summarise. A week that was
/// frozen with 145 XP contributes 145 forever.
final totalXpProvider = FutureProvider<int>((ref) async {
  ref.watch(journalEntriesProvider);
  final weeks = await ref.watch(databaseProvider).weeksDao.watchHistory().first;
  return weeks.fold<int>(0, (sum, week) => sum + week.xpAwarded);
});

/// Level, rank and progress towards the next.
final progressionProvider = FutureProvider<Progression>(
  (ref) async => levelFor(await ref.watch(totalXpProvider.future)),
);

/// Days logged in a row, ending today.
final streakProvider = FutureProvider<int>((ref) async {
  ref.watch(journalEntriesProvider);

  final today = Day.from(clock.now());
  final db = ref.watch(databaseProvider);

  // A year is more streak than anyone needs, and one query either way.
  final logged = await db.journalDao.loggedDaysIn(today.addDays(-400), today);

  return streakEndingAt(today, logged);
});

/// Days logged in the last seven — what Adrenaline actually pays on.
final recentLoggedDaysProvider = FutureProvider<int>((ref) async {
  ref.watch(journalEntriesProvider);

  final today = Day.from(clock.now());
  final db = ref.watch(databaseProvider);
  final logged = await db.journalDao.loggedDaysIn(today.addDays(-6), today);

  return logged.length;
});

final adrenalineProvider = FutureProvider<double>((ref) async {
  final days = await ref.watch(recentLoggedDaysProvider.future);
  return adrenalineFor(loggedDaysInLastWeek: days);
});

/// The five Signs for the selected day.
final signChargesProvider = FutureProvider<SignCharges>((ref) async {
  final items = ref.watch(journalEntriesProvider).valueOrNull ?? const [];
  final day = ref.watch(journalDayProvider);
  final profile = ref.watch(profileProvider).valueOrNull;
  final weight = ref.watch(latestWeightProvider).valueOrNull;
  final activity = ref.watch(dayActivityProvider).valueOrNull;
  final loggedDays = await ref.watch(recentLoggedDaysProvider.future);

  final totals = NutrientTotals.of(items.servings);
  final water = await ref.watch(databaseProvider).trackingDao.waterFor(day);

  return chargeSigns(
    totals: totals,
    vitality: scoreVitality(totals, bodyMassKg: weight),
    steps: activity?.steps ?? 0,
    distanceM: activity?.distanceM ?? 0,
    stepGoal: profile?.dailyStepGoal ?? 10000,
    loggedDaysInWeek: loggedDays,
    waterMl: water?.ml ?? 0,
    mealSlotsUsed: items.map((i) => i.entry.mealSlot).toSet().length,
  );
});

/// The most recent weigh-in, which is always visible.
///
/// Only its *interpretation* is sealed — see [weightChangeProvider].
final currentWeightProvider = Provider<double?>(
  (ref) => ref.watch(latestWeightProvider).valueOrNull,
);

/// The week's weight change, still sealed until the week closes.
///
/// Comes straight off the reckoning rather than being computed here, so the
/// character sheet and the Week's End screen can never disagree about whether
/// the seal has lifted.
final weightChangeProvider = Provider<AsyncValue<SealedValue<double?>>>(
  (ref) => ref.watch(weekReckoningProvider).whenData((r) => r.weightDeltaKg),
);

/// Days until the sealed node opens, for the line under it.
final daysUntilRevealProvider = Provider<int>(
  (ref) =>
      ref.watch(weekReckoningProvider).valueOrNull?.daysUntilReveal ?? 0,
);

/// Total steps across the last seven days, for the character sheet.
final weekStepsProvider = FutureProvider<int>((ref) async {
  ref.watch(activityTickProvider);

  final today = Day.from(clock.now());
  final rows = await ref
      .watch(databaseProvider)
      .trackingDao
      .activityInRange(today.addDays(-6), today);

  return rows.fold<int>(0, (sum, row) => sum + row.steps);
});

/// How many of the last seven days had any movement at all.
final activeDaysProvider = FutureProvider<int>((ref) async {
  ref.watch(activityTickProvider);

  final today = Day.from(clock.now());
  final rows = await ref
      .watch(databaseProvider)
      .trackingDao
      .activityInRange(today.addDays(-6), today);

  return activeDaysIn(rows.map(ActivitySync.fromRow));
});
