/// Vitality and Toxicity. Pure Dart.
///
/// Both are intake-relative by construction. Neither reads weight trend, TDEE,
/// or energy balance, so neither can leak the verdict — which is why both are
/// listed as always-visible in CLAUDE.md §1.
library;

import 'dart:math' as math;

import 'harm.dart';
import 'nutrition.dart';

/// How well the day was eaten, 0..100.
///
/// Four components, all ratios of the day against itself or against body mass:
/// nothing here knows how much the user was *meant* to eat.
class Vitality {
  const Vitality({
    required this.score,
    required this.fibre,
    required this.protein,
    required this.wholeFood,
    required this.sugarRestraint,
  });

  /// 0..100.
  final double score;

  /// Each component, 0..1, kept so the screen can say *why* rather than just
  /// showing a number that moves for unexplained reasons.
  final double fibre;
  final double protein;
  final double wholeFood;
  final double sugarRestraint;

  static const empty = Vitality(
    score: 0,
    fibre: 0,
    protein: 0,
    wholeFood: 0,
    sugarRestraint: 0,
  );
}

/// Weights of the four Vitality components. They sum to 1.
abstract final class _VitalityWeights {
  static const double fibre = 0.30;
  static const double wholeFood = 0.30;
  static const double protein = 0.25;
  static const double sugarRestraint = 0.15;
}

/// Scores the day's diet quality.
///
/// **An empty day scores zero, not full marks.** This is the trap the whole
/// function is arranged around: a day with nothing logged has no sugar, no
/// sodium and no ultra-processed food, so every "restraint" component would
/// read perfect. That would make not logging the highest-scoring strategy in
/// the app, which is precisely backwards — the app's one demand on the user is
/// that they log honestly.
///
/// [bodyMassKg] is the latest weigh-in. Weight is logged and shown daily; only
/// its interpretation is sealed, so using it here is safe. When there is no
/// weigh-in yet, protein falls back to a share-of-energy reading.
Vitality scoreVitality(NutrientTotals totals, {double? bodyMassKg}) {
  if (totals.isEmpty || totals.kcal <= 0) return Vitality.empty;

  // --- fibre density, against 14 g per 1000 kcal ---
  final fibre =
      (totals.fibrePer1000Kcal / fibreTargetPer1000Kcal).clamp(0.0, 1.0);

  // --- whole food share of energy ---
  // Unknown NOVA counts as neither whole nor ultra-processed, so a library of
  // hand-typed foods scores low here rather than falsely high. It recovers as
  // soon as foods carry real processing data.
  final wholeFood = totals.wholeFoodShare.clamp(0.0, 1.0);

  // --- protein adequacy ---
  final perKg = proteinPerKg(totals, bodyMassKg);
  final protein = perKg != null
      ? (perKg / proteinTargetPerKg).clamp(0.0, 1.0)
      // No weigh-in: fall back to protein's share of energy against the
      // bottom of its distribution range. Weaker, but not a guess about mass.
      : (totals.macroKcal <= 0
          ? 0.0
          : (totals.proteinKcal / totals.macroKcal / Amdr.protein.low)
              .clamp(0.0, 1.0));

  // --- restraint on free sugars ---
  final sugarShare = totals.macroKcal <= 0
      ? 0.0
      : totals.addedSugarG * Atwater.carbs / totals.macroKcal;
  final sugarRestraint =
      (1 - sugarShare / HarmLimits.freeSugarShare).clamp(0.0, 1.0);

  final score = (fibre * _VitalityWeights.fibre +
          wholeFood * _VitalityWeights.wholeFood +
          protein * _VitalityWeights.protein +
          sugarRestraint * _VitalityWeights.sugarRestraint) *
      100;

  return Vitality(
    score: score.clamp(0.0, 100.0),
    fibre: fibre.toDouble(),
    protein: protein.toDouble(),
    wholeFood: wholeFood.toDouble(),
    sugarRestraint: sugarRestraint.toDouble(),
  );
}

/// Accumulated harm, 0..100, carried across days like decoction toxicity.
abstract final class Toxicity {
  /// How much of yesterday's toxicity is still present today.
  ///
  /// 0.55 gives a half-life of a little over a day: a bad Friday still
  /// colours Saturday and is faint by Monday. The point of carrying anything
  /// forward at all is that a single indulgent evening should not be erased by
  /// the calendar turning over six hours later — but nor should it haunt a
  /// week, or the meter would stop responding to what was actually eaten.
  static const double dailyRetention = 0.55;

  /// Toxicity after one more day, given yesterday's figure and today's load.
  static double next(double previous, double todayLoad) =>
      (previous * dailyRetention + todayLoad).clamp(0.0, 100.0);

  /// Folds a run of daily loads, oldest first, into today's toxicity.
  ///
  /// Folding a bounded window rather than recursing back through all of
  /// history: the retention factor makes anything older than about a week
  /// contribute less than a percent, so [window] days is the whole of it.
  static double across(Iterable<double> dailyLoads) {
    var current = 0.0;
    for (final load in dailyLoads) {
      current = next(current, load);
    }
    return current;
  }

  /// Days of history worth folding. Beyond this the retained fraction is
  /// smaller than the meter can show.
  static const int window = 7;

  /// The oldest day that can still affect today's reading, as a day offset.
  static int get lookbackDays => window - 1;

  /// How far a single day's load can still be felt after [days] days.
  ///
  /// Exposed so the screen can explain the carry-over rather than appearing to
  /// invent it.
  static double residueAfter(int days) => math.pow(dailyRetention, days) as double;
}
