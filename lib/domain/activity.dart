/// Movement. Pure Dart.
///
/// A careful split runs through this file. **Steps, distance, Stamina and the
/// Aard charge are always visible**; they say how much the user moved, which
/// is an input like any other. **Active energy is not**, because it is a term
/// in expenditure, and intake against expenditure is the verdict. See
/// CLAUDE.md §1.
///
/// The split is enforced by [ActivityView], which simply has nowhere to put a
/// kcal figure — a widget cannot show what it was never handed.
library;

import 'dart:math' as math;

import 'day.dart';
import 'energy.dart';

/// One day's measured movement, as stored.
///
/// Carries active energy, because the weekly reckoning needs it. This type
/// belongs to the data and domain layers; it is deliberately *not* what the
/// activity UI is given.
class DayActivity {
  const DayActivity({
    required this.day,
    this.steps = 0,
    this.distanceM = 0,
    this.activeKcal,
    this.isManual = false,
  });

  final Day day;
  final int steps;
  final double distanceM;

  /// Active energy where the platform reported it.
  ///
  /// Never rendered. It exists so `reckon` can prefer a measured figure over
  /// one derived from step count.
  final double? activeKcal;

  /// True when the user typed these numbers rather than a device recording
  /// them. A manual entry always wins over a later sync.
  final bool isManual;

  bool get hasMovement => steps > 0 || distanceM > 0;

  double get distanceKm => distanceM / 1000;
}

/// What the activity UI is allowed to know.
///
/// There is no energy figure on this type and no way to add one without
/// editing this file, which is the point: a widget cannot leak a term of the
/// verdict it was never given. The same trick as `SealedValue`, one layer up.
class ActivityView {
  const ActivityView({
    required this.steps,
    required this.distanceM,
    required this.stepGoal,
    required this.stamina,
  });

  factory ActivityView.of(DayActivity activity, {required int stepGoal}) {
    return ActivityView(
      steps: activity.steps,
      distanceM: activity.distanceM,
      stepGoal: stepGoal,
      stamina: staminaFor(steps: activity.steps, stepGoal: stepGoal),
    );
  }

  static const empty = ActivityView(
    steps: 0,
    distanceM: 0,
    stepGoal: 10000,
    stamina: 0,
  );

  final int steps;
  final double distanceM;
  final int stepGoal;

  /// 0..100.
  final double stamina;

  double get distanceKm => distanceM / 1000;

  /// Progress towards the step goal, 0..1, for a bar that does not overflow.
  double get goalFraction =>
      stepGoal <= 0 ? 0 : (steps / stepGoal).clamp(0.0, 1.0);

  bool get metGoal => steps >= stepGoal;
}

/// Stamina: how much the user moved against their own step goal, 0..100.
///
/// A step goal is a target, but not a *verdict* target: it is set by the user
/// in character creation and has nothing to do with energy balance. Comparing
/// steps against it cannot be solved back into a deficit, which is why this is
/// on the always-visible side of CLAUDE.md §1 while expenditure is not.
double staminaFor({required int steps, required int stepGoal}) {
  if (stepGoal <= 0 || steps <= 0) return 0;
  return (steps / stepGoal * 100).clamp(0.0, 100.0);
}

/// The Aard sign's charge, 0..1 — activity, from steps and distance.
///
/// Weighted towards steps because that is what the phone actually counts;
/// distance is derived from stride on most days and would otherwise be the
/// same number twice. See [[03-Game-Design]] for the five Signs.
double aardCharge({
  required int steps,
  required double distanceM,
  required int stepGoal,
  double distanceGoalM = 7000,
}) {
  if (stepGoal <= 0) return 0;

  final bySteps = (steps / stepGoal).clamp(0.0, 1.0);
  final byDistance =
      distanceGoalM <= 0 ? 0.0 : (distanceM / distanceGoalM).clamp(0.0, 1.0);

  return (bySteps * 0.75 + byDistance * 0.25).clamp(0.0, 1.0);
}

/// Distance for a step count, when the platform did not report one.
///
/// Health Connect usually gives distance directly; this is the fallback for a
/// manual entry, where the user knows their step count and not their metres.
double distanceForSteps({required int steps, required double strideCm}) =>
    EnergyModel.distanceMetres(steps: steps, strideCm: strideCm);

/// How many of the last [window] days had any movement recorded.
///
/// Feeds the streak on the character sheet. Counts *recorded* days rather than
/// days over a goal: the app's demand on the user is that they log, not that
/// they perform.
int activeDaysIn(Iterable<DayActivity> days, {int window = 7}) {
  final recent = days.where((d) => d.hasMovement).toList();
  return math.min(recent.length, window);
}

/// Merges a measured day with what is already stored.
///
/// **A manual entry always wins.** If the user typed a number for a day, a
/// later Health Connect sync must not quietly replace it — they typed it
/// precisely because the device was wrong, and overwriting it would make the
/// override useless.
DayActivity mergeActivity({
  required DayActivity? existing,
  required DayActivity measured,
}) {
  if (existing != null && existing.isManual) return existing;
  return measured;
}
