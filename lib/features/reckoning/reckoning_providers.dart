import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/nutrition_adapter.dart';
import '../../domain/day.dart';
import '../../domain/energy.dart';
import '../../domain/nutrition.dart';
import '../../domain/reckoning.dart';
import '../../domain/reveal_gate.dart';
import '../../providers/app_providers.dart';
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
