import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/nutrition_adapter.dart';
import '../../data/week_archive.dart';
import '../../domain/day.dart';
import '../../domain/energy.dart';
import '../../domain/harm.dart';
import '../../domain/nutrition.dart';
import '../../domain/reckoning.dart';
import '../../domain/reveal_gate.dart';
import '../../domain/scoring.dart';
import '../../domain/week_summary.dart';
import '../../providers/app_providers.dart';
import '../ai/ai_providers.dart';
import '../journal/journal_providers.dart';

/// The one gate every verdict passes through.
///
/// Reads the week-end weekday from the profile, so changing it in Settings
/// moves the reveal everywhere at once.
final revealGateProvider = Provider<RevealGate>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  return RevealGate(weekEndsOn: profile?.weekEndsOn ?? DateTime.sunday);
});

/// Whether today is the day the week closes.
final isRevealDayProvider = Provider<bool>(
  (ref) => ref.watch(revealGateProvider).isRevealDay(Day.from(clock.now())),
);

/// Which week the Reckoning screen is showing. Defaults to the live one.
///
/// Holds any day inside the week; the gate and the reckoning derive the
/// boundaries, so this never has to be kept normalised.
final reckoningWeekProvider =
    NotifierProvider<ReckoningWeekNotifier, Day>(ReckoningWeekNotifier.new);

class ReckoningWeekNotifier extends Notifier<Day> {
  @override
  Day build() => Day.from(clock.now());

  void shiftWeeks(int weeks) => state = state.addDays(weeks * 7);

  void thisWeek() => state = Day.from(clock.now());

  /// The Reckoning never looks forward: a week that has not happened has
  /// nothing in it, and an empty future week reads like data loss.
  bool get canGoForward {
    final gate = ref.read(revealGateProvider);
    final today = Day.from(clock.now());
    return state.endOfWeek(weekEndsOn: gate.weekEndsOn).isBefore(
          today.endOfWeek(weekEndsOn: gate.weekEndsOn),
        );
  }
}

/// The week's verdict.
///
/// Note what this does *not* do: it never checks the gate itself. It gathers
/// the inputs and hands them to [reckon], which seals everything the gate does
/// not open — and, because the sealed branches are callbacks, never runs the
/// arithmetic at all on an ordinary weekday.
final weekReckoningProvider = FutureProvider<Reckoning>((ref) async {
  final gate = ref.watch(revealGateProvider);
  final week = ref.watch(reckoningWeekProvider);
  final profile = ref.watch(profileProvider).valueOrNull;

  // Recompute as food is logged, so the reveal day updates live.
  ref.watch(journalEntriesProvider);

  final db = ref.watch(databaseProvider);
  final today = Day.from(clock.now());

  final weekStart = week.startOfWeek(weekEndsOn: gate.weekEndsOn);
  final weekEnd = week.endOfWeek(weekEndsOn: gate.weekEndsOn);

  // --- weight at each end of the week ---
  final startWeight = await db.trackingDao.latestWeightOnOrBefore(weekStart);
  final endWeight = await db.trackingDao.latestWeightOnOrBefore(weekEnd);

  // The weight the energy model works from. A week-old figure is close enough
  // for a BMR estimate; the alternative is refusing to report anything.
  final bodyMass = endWeight?.kg ?? startWeight?.kg;

  // --- intake per day ---
  final items = await db.journalDao.forRange(weekStart, weekEnd);
  final intakeByDay = items.groupListsBy((i) => i.entry.day).map(
        (day, dayItems) =>
            MapEntry(day, NutrientTotals.of(dayItems.servings).kcal),
      );

  // --- measured movement per day ---
  final activity = await db.trackingDao.activityInRange(weekStart, weekEnd);
  final activityByDay = {for (final a in activity) a.day: a};

  final days = <DayEnergy>[];

  if (profile != null && bodyMass != null) {
    final bmr = EnergyModel.basalMetabolicRate(
      sex: profile.sex,
      weightKg: bodyMass,
      heightCm: profile.heightCm,
      ageYears: EnergyModel.ageFromBirthYear(profile.birthYear),
    );

    for (final day in weekStart.weekDays(weekEndsOn: gate.weekEndsOn)) {
      final measured = activityByDay[day];
      days.add(
        DayEnergy(
          day: day,
          intakeKcal: intakeByDay[day] ?? 0,
          expenditureKcal: expenditureFor(
            bmr: bmr,
            weightKg: bodyMass,
            strideCm: profile.strideCm,
            level: profile.activityLevel,
            steps: measured?.steps,
            reportedActiveKcal: measured?.activeKcal,
          ),
        ),
      );
    }
  }

  return reckon(
    anyDayOfWeek: week,
    today: today,
    gate: gate,
    days: days,
    startWeightKg: startWeight?.kg,
    endWeightKg: endWeight?.kg,
    heightCm: profile?.heightCm,
    ageYears:
        profile == null ? null : EnergyModel.ageFromBirthYear(profile.birthYear),
    sex: profile?.sex,
  );
});

/// Freezes a week and reads it back.
final weekArchiveProvider = Provider<WeekArchive>(
  (ref) => WeekArchive(
    weeks: ref.watch(databaseProvider).weeksDao,
    ai: ref.watch(openRouterClientProvider),
  ),
);

/// The week's frozen account, sealing it first if it has just closed.
///
/// Sealing on open is the only sensible trigger: there is no background job in
/// a serverless app, so a week closes when the user comes to read it. The
/// archive is idempotent, so opening the screen twice does not write twice or
/// spend a second AI call.
///
/// Returns null while the week is still sealed — there is nothing to archive
/// about a week that has not finished.
final archivedWeekProvider = FutureProvider<ArchivedWeek?>((ref) async {
  final reckoning = await ref.watch(weekReckoningProvider.future);
  if (!reckoning.isRevealed) return null;

  final archive = ref.watch(weekArchiveProvider);

  final existing = await archive.read(reckoning.weekStart);
  if (existing != null) return existing;

  final db = ref.watch(databaseProvider);
  final gate = ref.watch(revealGateProvider);
  final profile = ref.watch(profileProvider).valueOrNull;
  final stepGoal = profile?.dailyStepGoal ?? 10000;

  final days = reckoning.weekStart.weekDays(weekEndsOn: gate.weekEndsOn);

  // --- quality, day by day ---
  final items = await db.journalDao.forRange(
    reckoning.weekStart,
    reckoning.weekEnd,
  );
  final byDay = items.groupListsBy((i) => i.entry.day);

  var vitalitySum = 0.0;
  var toxicitySum = 0.0;
  var scoredDays = 0;

  final weight = await db.trackingDao.latestWeightOnOrBefore(reckoning.weekEnd);

  for (final day in days) {
    final dayItems = byDay[day];
    if (dayItems == null || dayItems.isEmpty) continue;

    final totals = NutrientTotals.of(dayItems.servings);
    vitalitySum += scoreVitality(totals, bodyMassKg: weight?.kg).score;
    toxicitySum += readToxins(totals).load;
    scoredDays++;
  }

  // --- movement ---
  final activity = await db.trackingDao.activityInRange(
    reckoning.weekStart,
    reckoning.weekEnd,
  );
  final steps = activity.fold<int>(0, (sum, a) => sum + a.steps);
  final goalDays = activity.where((a) => a.steps >= stepGoal).length;

  // --- weigh-ins for the chart ---
  final weights = await db.trackingDao.weightsInRange(
    reckoning.weekStart,
    reckoning.weekEnd,
  );

  final averageVitality = scoredDays == 0 ? 0.0 : vitalitySum / scoredDays;

  final xp = awardXp(
    loggedDays: reckoning.loggedDays,
    averageVitality: averageVitality,
    goalDays: goalDays,
  );

  final summary = WeekSummary(
    loggedDays: reckoning.loggedDays,
    energyBalanceKcal: reckoning.energyBalanceKcal.valueOrNull ?? 0,
    averageDailyBalanceKcal:
        reckoning.averageDailyBalanceKcal.valueOrNull ?? 0,
    projectedChangeKg: reckoning.projectedChangeKg.valueOrNull ?? 0,
    averageVitality: averageVitality,
    averageToxicity: scoredDays == 0 ? 0 : toxicitySum / scoredDays,
    steps: steps,
    goalDays: goalDays,
    xp: xp.total,
    weightDeltaKg: reckoning.weightDeltaKg.valueOrNull,
    trend: reckoning.trend.valueOrNull,
    bodyFatPercent: reckoning.bodyFatPercent.valueOrNull,
    dailyBalances: reckoning.dailyBalances.valueOrNull ?? const [],
    dailyWeights: [for (final w in weights) w.kg],
  );

  return archive.seal(
    reckoning: reckoning,
    summary: summary,
    // Cannot be built from a sealed week — see NarrativeFacts.
    facts: NarrativeFacts.from(
      reckoning,
      averageVitality: averageVitality,
      steps: steps,
    ),
  );
});
