/// The five Signs, and what charges them. Pure Dart.
///
/// Each is tied to a real behaviour rather than to a score the app invented —
/// see [[03-Game-Design]]. Like `FoodRarity` in T6, the enum lives here and
/// carries no colour: which sign is lit is a nutrition judgement, what it looks
/// like is the theme's business.
///
/// Every input is intake-relative or movement-relative. Nothing here reads
/// energy balance, so the whole row is safe on a daily screen (CLAUDE.md §1).
library;

import 'activity.dart';
import 'nutrition.dart';
import 'scoring.dart';

enum Sign {
  /// Protein adequacy / thermic effect.
  igni('Igni', 'Protein & burn'),

  /// Fibre and micronutrient coverage.
  quen('Quen', 'Fibre & shield'),

  /// Activity — steps and distance.
  aard('Aard', 'Force & motion'),

  /// Consistency — logging streak and glycemic stability.
  axii('Axii', 'Control & calm'),

  /// Hydration and meal-timing discipline.
  yrden('Yrden', 'Water & timing');

  const Sign(this.title, this.blurb);

  final String title;
  final String blurb;
}

/// Daily water intake the Yrden sign is measured against, in millilitres.
///
/// The commonly cited two litres. Not a medical target — a round number to
/// charge a glyph against, and the app says as much.
const int waterTargetMl = 2000;

/// Glycemic load above which a day stops counting as steady.
///
/// A load under 80 is conventionally a low-load day; Axii fades from there and
/// is dormant by twice that.
const double steadyGlycemicLoad = 80;

/// How charged each Sign is, 0..1.
class SignCharges {
  const SignCharges(this._charges);

  static const empty = SignCharges({});

  final Map<Sign, double> _charges;

  double operator [](Sign sign) => _charges[sign] ?? 0;

  /// In the order the character sheet shows them.
  List<(Sign, double)> get all =>
      [for (final sign in Sign.values) (sign, this[sign])];

  /// Signs at or above [threshold] — the ones actually doing something.
  List<Sign> lit({double threshold = 0.6}) =>
      [for (final sign in Sign.values) if (this[sign] >= threshold) sign];
}

/// Charges the five Signs from a day.
///
/// Takes already-computed pieces rather than raw rows, so this stays pure and
/// the same scoring that drives Alchemy drives the character sheet — one rule
/// each, in one place.
SignCharges chargeSigns({
  required NutrientTotals totals,
  required Vitality vitality,
  required int steps,
  required double distanceM,
  required int stepGoal,
  required int loggedDaysInWeek,
  int waterMl = 0,
  int mealSlotsUsed = 0,
}) {
  if (totals.isEmpty && steps == 0 && waterMl == 0) return SignCharges.empty;

  return SignCharges({
    // Protein adequacy, straight from the Vitality component. The two must
    // agree: a day that scores well on protein cannot leave Igni dark.
    Sign.igni: vitality.protein.clamp(0.0, 1.0),

    // Fibre density and whole-food share together — "shield" is about what the
    // diet is made of rather than how much of it there was.
    Sign.quen: (vitality.fibre * 0.6 + vitality.wholeFood * 0.4)
        .clamp(0.0, 1.0),

    Sign.aard: aardCharge(
      steps: steps,
      distanceM: distanceM,
      stepGoal: stepGoal,
    ),

    Sign.axii: _axii(
      loggedDaysInWeek: loggedDaysInWeek,
      glycemicLoad: totals.glycemicLoad,
    ),

    Sign.yrden: _yrden(waterMl: waterMl, mealSlotsUsed: mealSlotsUsed),
  });
}

/// Consistency: how much of the week was logged, and how steady the day was.
///
/// Weighted towards logging, because that is the behaviour the app actually
/// asks for. Glycemic stability is the secondary term — a day of even blood
/// sugar is the "control" half of the sign.
double _axii({required int loggedDaysInWeek, required double glycemicLoad}) {
  final consistency = (loggedDaysInWeek / 7).clamp(0.0, 1.0);

  // A day with no carbohydrate at all is not evidence of steadiness, so an
  // absent load scores neutral rather than perfect.
  final steadiness = glycemicLoad <= 0
      ? 0.5
      : (1 - (glycemicLoad - steadyGlycemicLoad) / steadyGlycemicLoad)
          .clamp(0.0, 1.0);

  return (consistency * 0.7 + steadiness * 0.3).clamp(0.0, 1.0);
}

/// Hydration and meal-timing discipline.
///
/// Meal spread is counted as *distinct slots used*, not clock times. The app
/// does not police when someone eats — eating across the day rather than in
/// one sitting is the only claim being made, and it is a weak one.
double _yrden({required int waterMl, required int mealSlotsUsed}) {
  final hydration = (waterMl / waterTargetMl).clamp(0.0, 1.0);
  // Three slots is a spread day. A fourth adds nothing.
  final spread = (mealSlotsUsed / 3).clamp(0.0, 1.0);

  return (hydration * 0.6 + spread * 0.4).clamp(0.0, 1.0);
}
