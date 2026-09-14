import 'dart:math' as math;

import 'package:clock/clock.dart';

/// Which Mifflin-St Jeor constant to use.
///
/// The formula was fitted on two groups and offers no third constant. Rather
/// than pretend otherwise, [unspecified] uses the midpoint and the app says so
/// — an estimate the user can correct, not a claim about them.
enum Sex {
  male('Male', 5),
  female('Female', -161),
  unspecified('Prefer not to say', -78);

  const Sex(this.label, this.mifflinConstant);

  final String label;
  final double mifflinConstant;
}

/// How much the user moves outside of anything a step counter would see.
///
/// Only used as a fallback: once step data exists, expenditure is measured
/// rather than guessed. See [EnergyModel.totalExpenditure].
enum ActivityLevel {
  hearthbound('Hearthbound', 'Desk-bound. Little walking.', 1.2),
  villageWalker('Village Walker', 'On your feet some of the day.', 1.375),
  roadWorn('Road-worn', 'Active job, or training most days.', 1.55),
  pathWalker('Path-walker', 'Hard training most days.', 1.725),
  monsterHunter('Monster Hunter', 'Physical job plus hard training.', 1.9);

  const ActivityLevel(this.title, this.blurb, this.multiplier);

  final String title;
  final String blurb;
  final double multiplier;
}

/// What the user is trying to do.
///
/// The daily adjustment is applied to maintenance. Note that nothing here is
/// ever shown against the day's intake — see CLAUDE.md §1.
enum Goal {
  loseFat('Shed the weight', -500),
  maintain('Hold the line', 0),
  gainMuscle('Build the frame', 250);

  const Goal(this.title, this.dailyKcalAdjustment);

  final String title;

  /// Daily energy adjustment against maintenance, in kcal.
  ///
  /// -500/day is about 0.45 kg of fat a week, taking 7,700 kcal per kg. The
  /// surplus is deliberately smaller: muscle cannot be gained as fast as fat
  /// can be lost, and a larger surplus mostly adds fat.
  final int dailyKcalAdjustment;
}

/// Energy arithmetic. Pure Dart, no Flutter, no database.
abstract final class EnergyModel {
  /// Energy in one kilogram of body fat, in kcal.
  static const double kcalPerKgFat = 7700;

  /// Multiplier applied to BMR for a person who is awake, digesting, and
  /// moving only incidentally.
  ///
  /// This already contains roughly [stepsInSedentaryBaseline] steps of walking,
  /// which is why measured walking is only counted above that figure.
  static const double sedentaryMultiplier = 1.2;

  /// Steps already accounted for by [sedentaryMultiplier].
  ///
  /// Without this, a day's walking would be counted twice: once inside the
  /// sedentary baseline and again from the step counter.
  static const int stepsInSedentaryBaseline = 3000;

  /// Net cost of walking, in kcal per kg of body mass per km.
  ///
  /// Net, not gross — resting metabolism over the same period is already
  /// covered by the baseline, so only the extra cost of moving is added.
  static const double walkingKcalPerKgPerKm = 0.5;

  /// Basal metabolic rate, Mifflin-St Jeor.
  ///
  /// Chosen over Harris-Benedict because it is the more accurate of the two on
  /// modern populations. It is still an estimate with real error bars on any
  /// individual, which is part of why the app reveals trends weekly rather than
  /// pretending to daily precision.
  static double basalMetabolicRate({
    required Sex sex,
    required double weightKg,
    required double heightCm,
    required int ageYears,
  }) {
    final raw = 10 * weightKg + 6.25 * heightCm - 5 * ageYears + sex.mifflinConstant;
    return math.max(0, raw);
  }

  /// Energy burned before any measured movement.
  static double restingExpenditure(double bmr) => bmr * sedentaryMultiplier;

  /// Distance covered by [steps], in metres.
  static double distanceMetres({required int steps, required double strideCm}) =>
      steps * strideCm / 100;

  /// Net energy of walking [steps], counting only what the sedentary baseline
  /// does not already include.
  static double walkingEnergy({
    required int steps,
    required double strideCm,
    required double weightKg,
  }) {
    final billable = math.max(0, steps - stepsInSedentaryBaseline);
    final km = distanceMetres(steps: billable, strideCm: strideCm) / 1000;
    return walkingKcalPerKgPerKm * weightKg * km;
  }

  /// Energy from movement on top of [restingExpenditure].
  ///
  /// When the platform reports active energy it is preferred outright rather
  /// than added: Health Connect's figure already includes walking, so summing
  /// the two would count the same steps twice.
  static double activityEnergy({
    required int steps,
    required double strideCm,
    required double weightKg,
    double? reportedActiveKcal,
  }) {
    if (reportedActiveKcal != null && reportedActiveKcal > 0) {
      return reportedActiveKcal;
    }
    return walkingEnergy(steps: steps, strideCm: strideCm, weightKg: weightKg);
  }

  /// Total daily energy expenditure from *measured* movement.
  static double totalExpenditure({
    required double bmr,
    required int steps,
    required double strideCm,
    required double weightKg,
    double? reportedActiveKcal,
  }) {
    return restingExpenditure(bmr) +
        activityEnergy(
          steps: steps,
          strideCm: strideCm,
          weightKg: weightKg,
          reportedActiveKcal: reportedActiveKcal,
        );
  }

  /// Total daily energy expenditure guessed from a self-described lifestyle.
  ///
  /// The fallback for days with no step data. Self-reported activity is
  /// notoriously optimistic, which is exactly why measured movement wins when
  /// it is available.
  static double estimatedExpenditure({
    required double bmr,
    required ActivityLevel level,
  }) =>
      bmr * level.multiplier;

  /// Daily energy target for a goal, against a maintenance figure.
  ///
  /// Floored at 1,200 kcal: an aggressive deficit on a small person can drive
  /// the arithmetic somewhere no app should send anyone.
  static double dailyTarget({
    required double maintenance,
    required Goal goal,
  }) =>
      math.max(1200, maintenance + goal.dailyKcalAdjustment);

  /// Typical step length from height, in cm.
  ///
  /// About 0.414 of standing height across populations. Only a starting point —
  /// the user can measure their own and overwrite it.
  static double strideFromHeight(double heightCm) => heightCm * 0.414;

  /// Age in whole years, read through `package:clock` so tests can freeze it.
  static int ageFromBirthYear(int birthYear) => clock.now().year - birthYear;

  /// Body mass index. Reported as context, never as a verdict.
  static double bmi({required double weightKg, required double heightCm}) {
    final m = heightCm / 100;
    return m <= 0 ? 0 : weightKg / (m * m);
  }
}
