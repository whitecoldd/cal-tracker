/// The week's verdict. Pure Dart.
///
/// Everything in here answers, in one form or another, "am I losing or gaining
/// weight?" — so every field is a [SealedValue] and none of them is computed
/// unless the week has closed. See CLAUDE.md §1.
library;

import 'dart:math' as math;

import 'day.dart';
import 'energy.dart';
import 'reveal_gate.dart';
import 'sealed_value.dart';

/// One day's energy in and out.
///
/// A plain value type so the whole reckoning can be tested against fixtures
/// without a database. Expenditure is supplied rather than derived here
/// because it depends on measured steps, which is T10's business.
class DayEnergy {
  const DayEnergy({
    required this.day,
    required this.intakeKcal,
    required this.expenditureKcal,
  });

  final Day day;
  final double intakeKcal;
  final double expenditureKcal;

  /// Positive is a surplus, negative a deficit.
  double get balanceKcal => intakeKcal - expenditureKcal;

  /// A day with nothing logged at all.
  ///
  /// Distinguished from a genuine zero-intake day because an unlogged day must
  /// not be counted as a day of total fasting — see [Reckoning.loggedDays].
  bool get wasLogged => intakeKcal > 0;
}

/// Which way the body actually went.
enum WeightTrend {
  falling('Falling'),
  holding('Holding'),
  rising('Rising');

  const WeightTrend(this.label);

  final String label;
}

/// Weekly weight change below which the scale is reporting noise.
///
/// Day-to-day weight swings of a kilogram from water, glycogen and gut
/// contents are ordinary. Calling a 0.2 kg move a trend is how a tracker
/// teaches someone to react to nothing — which is the behaviour this whole
/// app exists to prevent.
const double weightNoiseKg = 0.3;

/// The verdict for one week.
class Reckoning {
  const Reckoning({
    required this.weekStart,
    required this.weekEnd,
    required this.loggedDays,
    required this.daysUntilReveal,
    required this.energyBalanceKcal,
    required this.averageDailyBalanceKcal,
    required this.weightDeltaKg,
    required this.trend,
    required this.projectedChangeKg,
    required this.bodyFatPercent,
    required this.dailyBalances,
  });

  final Day weekStart;
  final Day weekEnd;

  /// How many of the week's days were actually logged.
  ///
  /// **Not sealed.** It says nothing about gaining or losing, and it is the
  /// one figure that tells the user how much the sealed ones are worth — a
  /// verdict drawn from two logged days deserves to be read with suspicion.
  final int loggedDays;

  /// Days until this week closes. Zero on the day itself, and for any week
  /// already closed.
  ///
  /// **Not sealed**, and computed here rather than in the widget so the screen
  /// never has to read the clock itself. A calendar fact, not a verdict — and
  /// a seal that says when it opens reads as deliberate rather than broken.
  final int daysUntilReveal;

  /// Intake minus expenditure across the week. Positive is a surplus.
  final SealedValue<double> energyBalanceKcal;

  /// The same figure per logged day, which is the one people think in.
  final SealedValue<double> averageDailyBalanceKcal;

  /// Measured weight change across the week, in kg.
  ///
  /// Null inside [Revealed] when there were not two weigh-ins to compare.
  final SealedValue<double?> weightDeltaKg;

  /// The measured direction, with a noise band applied.
  final SealedValue<WeightTrend?> trend;

  /// What the energy balance alone predicts, in kg.
  ///
  /// Shown beside the measured delta rather than instead of it: the gap
  /// between the two is the interesting part, and it is usually water.
  final SealedValue<double> projectedChangeKg;

  /// Body fat estimate, per cent.
  final SealedValue<double?> bodyFatPercent;

  /// Each logged day's own balance, oldest first — the shape of the week.
  ///
  /// Sealed like the rest. Plotting these before the week closes would draw
  /// the verdict as a picture, which is no better than printing it.
  final SealedValue<List<double>> dailyBalances;

  /// Whether this week may be read at all.
  ///
  /// Derived from one field rather than stored, so it cannot disagree with the
  /// values themselves.
  bool get isRevealed => energyBalanceKcal.isRevealed;
}

/// Computes a week's verdict, sealing everything the gate does not open.
///
/// [days] should be the week's seven days; missing ones may simply be absent.
/// [startWeightKg] and [endWeightKg] are the nearest weigh-ins at each end.
Reckoning reckon({
  required Day anyDayOfWeek,
  required Day today,
  required RevealGate gate,
  required List<DayEnergy> days,
  double? startWeightKg,
  double? endWeightKg,
  double? heightCm,
  int? ageYears,
  Sex? sex,
}) {
  final weekStart = anyDayOfWeek.startOfWeek(weekEndsOn: gate.weekEndsOn);
  final weekEnd = anyDayOfWeek.endOfWeek(weekEndsOn: gate.weekEndsOn);

  final logged = days.where((d) => d.wasLogged).toList(growable: false);

  // Every figure below is built through `gate.gate`, so on a non-reveal day
  // none of this arithmetic runs at all.
  final balance = gate.gate<double>(
    anyDayOfWeek,
    today: today,
    compute: () => logged.fold<double>(0, (sum, d) => sum + d.balanceKcal),
  );

  final averageBalance = gate.gate<double>(
    anyDayOfWeek,
    today: today,
    compute: () {
      if (logged.isEmpty) return 0;
      final total = logged.fold<double>(0, (sum, d) => sum + d.balanceKcal);
      // Per *logged* day, not per calendar day: dividing a four-day week by
      // seven would report a deficit the user never ran.
      return total / logged.length;
    },
  );

  final delta = gate.gate<double?>(
    anyDayOfWeek,
    today: today,
    compute: () {
      if (startWeightKg == null || endWeightKg == null) return null;
      return endWeightKg - startWeightKg;
    },
  );

  final trend = gate.gate<WeightTrend?>(
    anyDayOfWeek,
    today: today,
    compute: () {
      if (startWeightKg == null || endWeightKg == null) return null;
      final change = endWeightKg - startWeightKg;
      if (change.abs() < weightNoiseKg) return WeightTrend.holding;
      return change < 0 ? WeightTrend.falling : WeightTrend.rising;
    },
  );

  final projected = gate.gate<double>(
    anyDayOfWeek,
    today: today,
    compute: () {
      final total = logged.fold<double>(0, (sum, d) => sum + d.balanceKcal);
      return total / EnergyModel.kcalPerKgFat;
    },
  );

  final dailyBalances = gate.gate<List<double>>(
    anyDayOfWeek,
    today: today,
    compute: () => [for (final d in logged) d.balanceKcal],
  );

  final bodyFat = gate.gate<double?>(
    anyDayOfWeek,
    today: today,
    compute: () => estimateBodyFatPercent(
      weightKg: endWeightKg,
      heightCm: heightCm,
      ageYears: ageYears,
      sex: sex,
    ),
  );

  return Reckoning(
    weekStart: weekStart,
    weekEnd: weekEnd,
    loggedDays: logged.length,
    daysUntilReveal: gate.daysUntilReveal(anyDayOfWeek, today: today),
    energyBalanceKcal: balance,
    averageDailyBalanceKcal: averageBalance,
    weightDeltaKg: delta,
    trend: trend,
    projectedChangeKg: projected,
    bodyFatPercent: bodyFat,
    dailyBalances: dailyBalances,
  );
}

/// Body fat estimate from BMI, age and sex — the Deurenberg equation.
///
/// Returns null when any input is missing. This is a population regression with
/// error bars of several points on an individual, which is exactly why it is
/// sealed with the rest of the verdict and shown once a week rather than
/// tracked daily as though it were measured.
double? estimateBodyFatPercent({
  required double? weightKg,
  required double? heightCm,
  required int? ageYears,
  required Sex? sex,
}) {
  if (weightKg == null || heightCm == null || ageYears == null || sex == null) {
    return null;
  }
  if (weightKg <= 0 || heightCm <= 0) return null;

  final bmi = EnergyModel.bmi(weightKg: weightKg, heightCm: heightCm);

  // The equation's sex term is 1 for men and 0 for women. `unspecified` takes
  // the midpoint, the same compromise Sex.mifflinConstant makes — an estimate
  // the user can disbelieve, not a claim about them.
  final sexTerm = switch (sex) {
    Sex.male => 1.0,
    Sex.female => 0.0,
    Sex.unspecified => 0.5,
  };

  final percent = 1.20 * bmi + 0.23 * ageYears - 10.8 * sexTerm - 5.4;
  return percent.clamp(3.0, 70.0);
}

/// Expenditure for a day, from whatever is known about it.
///
/// Falls back to the self-described activity level when there is no step data,
/// which is most days until Health Connect lands in T10.
double expenditureFor({
  required double bmr,
  required double weightKg,
  required double strideCm,
  required ActivityLevel level,
  int? steps,
  double? reportedActiveKcal,
}) {
  if (steps == null || steps <= 0) {
    return EnergyModel.estimatedExpenditure(bmr: bmr, level: level);
  }
  return EnergyModel.totalExpenditure(
    bmr: bmr,
    steps: steps,
    strideCm: strideCm,
    weightKg: weightKg,
    reportedActiveKcal: reportedActiveKcal,
  );
}

/// Rounds a kcal figure for display without implying precision it lacks.
///
/// Energy balance carries the error of a BMR estimate, a step count and a
/// hundred portion guesses. Reporting it to the calorie would be a lie about
/// how well it is known.
int roundBalance(double kcal) => (kcal / 10).round() * 10;

/// The largest absolute weekly change the projection is willing to state.
///
/// Beyond this something is wrong with the data — a mis-typed portion, a
/// missing week of logs — and a confident "you gained 4 kg" would be worse
/// than saying nothing.
const double maxCredibleWeeklyKg = 2.0;

/// Whether a projected or measured change is worth believing.
bool isCredible(double kg) => kg.abs() <= maxCredibleWeeklyKg;

/// Clamps a change to the credible range, keeping its sign.
double clampCredible(double kg) =>
    kg.sign * math.min(kg.abs(), maxCredibleWeeklyKg);
