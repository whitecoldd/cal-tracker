/// The nutrition engine. Pure Dart, no Flutter, no database.
///
/// Everything here is intake-relative: it describes what was eaten and how it
/// was composed, never what was eaten *against expenditure*. That is not a
/// style preference — a macro target derived from TDEE can be subtracted back
/// into a deficit, which would answer "am I losing weight?" on a daily screen.
/// See CLAUDE.md §1.
library;

/// Energy per gram of each macronutrient, in kcal — the Atwater factors.
abstract final class Atwater {
  static const double protein = 4;
  static const double carbs = 4;
  static const double fat = 9;
  static const double alcohol = 7;
}

/// A food's nutrient panel per 100 g (or 100 ml).
///
/// A plain value type rather than the drift row, because `domain/` must not
/// depend on `data/`. The DAO layer adapts its rows into these.
class FoodPanel {
  const FoodPanel({
    required this.kcal,
    this.proteinG = 0,
    this.carbsG = 0,
    this.sugarG = 0,
    this.addedSugarG,
    this.fatG = 0,
    this.satFatG = 0,
    this.transFatG,
    this.fibreG = 0,
    this.sodiumMg = 0,
    this.alcoholG = 0,
    this.glycemicIndex,
    this.novaGroup,
    this.additiveCount = 0,
  });

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double sugarG;

  /// Free sugars specifically, which is what the WHO limit is about.
  ///
  /// Null means unknown, and is deliberately not treated as zero: a thin
  /// record would otherwise be exonerated for free.
  final double? addedSugarG;

  final double fatG;
  final double satFatG;
  final double? transFatG;
  final double fibreG;
  final double sodiumMg;
  final double alcoholG;

  /// Null where the food has too little carbohydrate for the measure to mean
  /// anything — which is not the same as a GI of zero.
  final int? glycemicIndex;

  /// NOVA processing group, 1 (unprocessed) to 4 (ultra-processed).
  final int? novaGroup;

  final int additiveCount;

  /// True when this food is ultra-processed.
  ///
  /// Unknown counts as *not* ultra-processed. Flagging an unknown food as
  /// ultra-processed would put a red mark on every hand-typed whole food.
  bool get isUltraProcessed => novaGroup == 4;

  /// True when the food is unprocessed or minimally processed.
  bool get isWholeFood => novaGroup != null && novaGroup! <= 2;
}

/// A panel plus the amount actually eaten.
class Serving {
  const Serving({required this.food, required this.grams});

  final FoodPanel food;
  final double grams;

  /// Scale factor from the per-100g panel to this portion.
  double get portions => grams / 100.0;

  double get kcal => food.kcal * portions;
  double get proteinG => food.proteinG * portions;
  double get carbsG => food.carbsG * portions;
  double get sugarG => food.sugarG * portions;
  double get fatG => food.fatG * portions;
  double get satFatG => food.satFatG * portions;
  double get fibreG => food.fibreG * portions;
  double get sodiumMg => food.sodiumMg * portions;
  double get alcoholG => food.alcoholG * portions;

  double? get addedSugarG =>
      food.addedSugarG == null ? null : food.addedSugarG! * portions;

  double? get transFatG =>
      food.transFatG == null ? null : food.transFatG! * portions;

  /// Glycemic load for this portion: GI weighted by the carbohydrate actually
  /// eaten. Null where the food has no meaningful GI.
  double? get glycemicLoad {
    final gi = food.glycemicIndex;
    if (gi == null) return null;
    return gi * carbsG / 100.0;
  }
}

/// What a set of servings adds up to.
///
/// Absolute figures only. There is no target, no remainder and no percentage
/// of any goal in here, because comparing intake against expenditure is the
/// verdict and the verdict waits for the week to close.
class NutrientTotals {
  const NutrientTotals({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.sugarG,
    required this.addedSugarG,
    required this.fatG,
    required this.satFatG,
    required this.transFatG,
    required this.fibreG,
    required this.sodiumMg,
    required this.alcoholG,
    required this.glycemicLoad,
    required this.itemCount,
    required this.ultraProcessedKcal,
    required this.wholeFoodKcal,
    required this.additiveCount,
    required this.carbKcalWithKnownGi,
  });

  factory NutrientTotals.of(Iterable<Serving> servings) {
    var kcal = 0.0;
    var protein = 0.0;
    var carbs = 0.0;
    var sugar = 0.0;
    var addedSugar = 0.0;
    var fat = 0.0;
    var satFat = 0.0;
    var transFat = 0.0;
    var fibre = 0.0;
    var sodium = 0.0;
    var alcohol = 0.0;
    var load = 0.0;
    var count = 0;
    var ultraKcal = 0.0;
    var wholeKcal = 0.0;
    var additives = 0;
    var giCarbKcal = 0.0;

    for (final s in servings) {
      kcal += s.kcal;
      protein += s.proteinG;
      carbs += s.carbsG;
      sugar += s.sugarG;
      addedSugar += s.addedSugarG ?? 0;
      fat += s.fatG;
      satFat += s.satFatG;
      transFat += s.transFatG ?? 0;
      fibre += s.fibreG;
      sodium += s.sodiumMg;
      alcohol += s.alcoholG;
      count++;
      additives += s.food.additiveCount;

      if (s.food.isUltraProcessed) ultraKcal += s.kcal;
      if (s.food.isWholeFood) wholeKcal += s.kcal;

      final gl = s.glycemicLoad;
      if (gl != null) {
        load += gl;
        giCarbKcal += s.carbsG * Atwater.carbs;
      }
    }

    return NutrientTotals(
      kcal: kcal,
      proteinG: protein,
      carbsG: carbs,
      sugarG: sugar,
      addedSugarG: addedSugar,
      fatG: fat,
      satFatG: satFat,
      transFatG: transFat,
      fibreG: fibre,
      sodiumMg: sodium,
      alcoholG: alcohol,
      glycemicLoad: load,
      itemCount: count,
      ultraProcessedKcal: ultraKcal,
      wholeFoodKcal: wholeKcal,
      additiveCount: additives,
      carbKcalWithKnownGi: giCarbKcal,
    );
  }

  static const empty = NutrientTotals(
    kcal: 0,
    proteinG: 0,
    carbsG: 0,
    sugarG: 0,
    addedSugarG: 0,
    fatG: 0,
    satFatG: 0,
    transFatG: 0,
    fibreG: 0,
    sodiumMg: 0,
    alcoholG: 0,
    glycemicLoad: 0,
    itemCount: 0,
    ultraProcessedKcal: 0,
    wholeFoodKcal: 0,
    additiveCount: 0,
    carbKcalWithKnownGi: 0,
  );

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double sugarG;

  /// Free sugars where known. Foods with no figure contribute nothing, which
  /// understates rather than invents.
  final double addedSugarG;

  final double fatG;
  final double satFatG;
  final double transFatG;
  final double fibreG;
  final double sodiumMg;
  final double alcoholG;

  /// Sum of each item's glycemic load. Items with no GI contribute nothing.
  final double glycemicLoad;

  final int itemCount;

  /// Energy from NOVA-4 foods, and from NOVA 1–2 foods.
  final double ultraProcessedKcal;
  final double wholeFoodKcal;

  final int additiveCount;

  /// Carbohydrate energy from the foods that actually carried a GI.
  ///
  /// The denominator for [averageGlycemicIndex]: averaging over *all* carbs
  /// would silently treat an unknown GI as zero and drag the figure down.
  final double carbKcalWithKnownGi;

  bool get isEmpty => itemCount == 0;

  /// Energy from each macronutrient, in kcal.
  double get proteinKcal => proteinG * Atwater.protein;
  double get carbKcal => carbsG * Atwater.carbs;
  double get fatKcal => fatG * Atwater.fat;
  double get alcoholKcal => alcoholG * Atwater.alcohol;

  /// Energy implied by the macros, which is what the shares are taken against.
  ///
  /// Not [kcal]: label energy and the Atwater sum routinely disagree by a few
  /// percent, and shares taken against a different denominator than their own
  /// numerators would not add to 100.
  double get macroKcal => proteinKcal + carbKcal + fatKcal + alcoholKcal;

  /// Carbohydrate-weighted mean GI of the foods that reported one.
  ///
  /// Null when nothing eaten carried a GI at all.
  double? get averageGlycemicIndex {
    if (carbKcalWithKnownGi <= 0) return null;
    final carbsWithGi = carbKcalWithKnownGi / Atwater.carbs;
    return glycemicLoad * 100.0 / carbsWithGi;
  }

  /// Share of energy that came from ultra-processed food, 0..1.
  double get ultraProcessedShare => kcal <= 0 ? 0 : ultraProcessedKcal / kcal;

  /// Share of energy that came from whole or minimally processed food, 0..1.
  double get wholeFoodShare => kcal <= 0 ? 0 : wholeFoodKcal / kcal;

  /// Fibre per 1000 kcal — density, not quantity.
  ///
  /// The right way to read fibre: 20 g is good on a small day and thin on a
  /// large one, and a flat target rewards simply eating more.
  double get fibrePer1000Kcal => kcal <= 0 ? 0 : fibreG / kcal * 1000;
}

/// One macronutrient's share of the day's own energy, against the range it is
/// usually expected to fall in.
///
/// This is the only reference the Alchemy vials use for carbohydrate and fat,
/// and it is deliberately a *composition* measure. It says how the day was put
/// together, never whether there was enough of it — so no arrangement of these
/// numbers can be solved back into an energy balance.
class MacroShare {
  const MacroShare({
    required this.label,
    required this.grams,
    required this.share,
    required this.rangeLow,
    required this.rangeHigh,
  });

  final String label;
  final double grams;

  /// Fraction of the day's macro energy, 0..1.
  final double share;

  /// The Acceptable Macronutrient Distribution Range for this macro, as
  /// fractions. Public dietary guidance, not a goal the app has set.
  final double rangeLow;
  final double rangeHigh;

  bool get isBelowRange => share < rangeLow;
  bool get isAboveRange => share > rangeHigh;
  bool get isInRange => !isBelowRange && !isAboveRange;

  /// Where the share sits within the range, 0..1, for the vial fill.
  ///
  /// Clamped just past 1 so an over-range day visibly overfills rather than
  /// reading as a full, satisfied flask.
  double get fillFraction {
    if (rangeHigh <= 0) return 0;
    return (share / rangeHigh).clamp(0.0, 1.25);
  }
}

/// The acceptable distribution ranges, as fractions of energy.
///
/// These are the widely published AMDR figures for adults. They describe how
/// diets are usually composed; they are not a target this app has chosen, and
/// nothing about them depends on how much the user is meant to eat.
abstract final class Amdr {
  static const carbs = (low: 0.45, high: 0.65);
  static const fat = (low: 0.20, high: 0.35);
  static const protein = (low: 0.10, high: 0.35);
}

/// Macro composition of a day, for the Alchemy vials.
///
/// Returns an empty list for a day with no food: a composition of nothing is
/// not a balanced composition, and showing three empty-but-in-range vials
/// would quietly reward not logging.
List<MacroShare> macroShares(NutrientTotals totals) {
  final total = totals.macroKcal;
  if (total <= 0) return const [];

  MacroShare share(
    String label,
    double grams,
    double kcal,
    ({double low, double high}) range,
  ) {
    return MacroShare(
      label: label,
      grams: grams,
      share: kcal / total,
      rangeLow: range.low,
      rangeHigh: range.high,
    );
  }

  return [
    share('Protein', totals.proteinG, totals.proteinKcal, Amdr.protein),
    share('Carbs', totals.carbsG, totals.carbKcal, Amdr.carbs),
    share('Fat', totals.fatG, totals.fatKcal, Amdr.fat),
  ];
}

/// Protein adequacy in grams per kilogram of body mass.
///
/// Body mass is used, not energy expenditure. Weight is logged and visible
/// every day — only its *interpretation* is sealed — so this reference leaks
/// nothing about energy balance.
///
/// Null when there is no weigh-in to work from.
double? proteinPerKg(NutrientTotals totals, double? bodyMassKg) {
  if (bodyMassKg == null || bodyMassKg <= 0) return null;
  return totals.proteinG / bodyMassKg;
}

/// Protein intake widely regarded as ample for an active adult, in g/kg.
///
/// Used as the protein vial's adequacy mark and by the Igni sign. Higher than
/// the 0.8 g/kg RDA, which is a floor for avoiding deficiency rather than a
/// figure anyone training would aim at.
const double proteinTargetPerKg = 1.6;

/// Daily fibre intake used as the fibre vial's mark, in grams.
const double fibreTargetG = 30;

/// Fibre density regarded as good, in grams per 1000 kcal.
const double fibreTargetPer1000Kcal = 14;
