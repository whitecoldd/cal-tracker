/// The harm model. Pure Dart.
///
/// Drawn from public food data and public dietary guidance, and shown as game
/// flavour. Every string in here is **descriptive, never diagnostic**: it says
/// what was eaten against a published guideline, and never what that will do to
/// the person eating it. See CLAUDE.md §7. The disclaimer that accompanies all
/// of this — *lore, not a physician* — is [harmDisclaimer].
library;

import 'nutrition.dart';

/// The standing disclaimer that must appear on every harm surface.
const String harmDisclaimer =
    'Lore, not a physician. Drawn from public food data — not medical advice.';

/// A kind of damage the app tracks.
///
/// Each carries the guideline it is measured against, so the number on screen
/// can always be explained rather than merely asserted.
enum HarmKind {
  additives(
    'Alchemical residue',
    'Additives and E-numbers listed for this food.',
  ),
  ultraProcessed(
    'Refined matter',
    'Energy from ultra-processed food (NOVA group 4).',
  ),
  addedSugar(
    'Sweet rot',
    'Free sugars against the WHO guideline of under 10% of energy.',
  ),
  sodium(
    'Salt burn',
    'Sodium against the WHO guideline of 2,000 mg a day.',
  ),
  saturatedFat(
    'Thick blood',
    'Saturated fat against the guideline of under 10% of energy.',
  ),
  transFat(
    'Rancid oil',
    'Industrial trans fat, which the WHO recommends eliminating.',
  ),
  alcohol(
    'Strong drink',
    'Alcohol in units. No amount is described as beneficial.',
  );

  const HarmKind(this.title, this.basis);

  /// The in-world name shown on the card.
  final String title;

  /// Plain-language statement of what this is measured against.
  final String basis;
}

/// One harm reading.
class HarmFlag {
  const HarmFlag({
    required this.kind,
    required this.severity,
    required this.detail,
  });

  final HarmKind kind;

  /// 0..1, where 1 means "at or past the guideline". Not capped at the
  /// guideline internally — see [Toxins.load] — but clamped for display.
  final double severity;

  /// The measured figure, in words. Descriptive only.
  final String detail;

  /// Whether this is worth showing at all.
  ///
  /// A twentieth of the guideline, not merely non-zero. Almost every real food
  /// carries a trace of something, and listing a curse that reads "1 g — 0% of
  /// energy" is noise that makes the panel harder to scan and devalues the
  /// readings that matter.
  bool get isNotable => severity >= notableSeverity;

  /// The threshold at which a reading is worth a line on the screen.
  static const double notableSeverity = 0.05;
}

/// Guideline figures, all from public dietary guidance.
abstract final class HarmLimits {
  /// WHO daily sodium guideline, in mg.
  static const double sodiumMg = 2000;

  /// WHO free-sugar guideline, as a share of energy.
  static const double freeSugarShare = 0.10;

  /// Saturated fat guideline, as a share of energy.
  static const double satFatShare = 0.10;

  /// Trans fat guideline, as a share of energy. The WHO position is
  /// elimination, so this is a ceiling rather than an allowance.
  static const double transFatShare = 0.01;

  /// Grams of ethanol in one UK unit.
  static const double gramsPerAlcoholUnit = 8;

  /// Daily alcohol units used as the reference point. UK guidance is 14 units
  /// a week spread over three or more days.
  static const double alcoholUnitsPerDay = 2;

  /// Share of energy from NOVA-4 food at which the flag reads as full.
  static const double ultraProcessedShare = 0.50;

  /// Distinct additives in a day at which the flag reads as full.
  static const int additiveCount = 10;
}

/// The day's harm readings, and the single number the Toxicity meter shows.
class Toxins {
  const Toxins({required this.flags, required this.load});

  /// Every reading, notable ones first.
  final List<HarmFlag> flags;

  /// The day's own harm, 0..100, before any carry-over from previous days.
  ///
  /// Kept separate from the displayed Toxicity because toxicity accumulates
  /// across days — see `scoring.dart`.
  final double load;

  static const empty = Toxins(flags: [], load: 0);

  /// Readings worth drawing attention to.
  List<HarmFlag> get notable =>
      flags.where((f) => f.isNotable).toList(growable: false);

  HarmFlag? operator [](HarmKind kind) {
    for (final f in flags) {
      if (f.kind == kind) return f;
    }
    return null;
  }
}

/// Weight of each harm in the day's total load.
///
/// Trans fat outweighs everything per unit because the guidance is
/// elimination rather than moderation; additives weigh least because an
/// E-number is a statement about processing, not about dose.
const Map<HarmKind, double> _weights = {
  HarmKind.transFat: 22,
  HarmKind.addedSugar: 20,
  HarmKind.sodium: 18,
  HarmKind.saturatedFat: 16,
  HarmKind.alcohol: 14,
  HarmKind.ultraProcessed: 12,
  HarmKind.additives: 8,
};

/// Reads the day's harm.
///
/// An empty day returns [Toxins.empty]: no food is no harm, but see
/// `scoring.dart` for why it is emphatically *not* a good day.
Toxins readToxins(NutrientTotals totals) {
  if (totals.isEmpty) return Toxins.empty;

  final energy = totals.macroKcal;
  final flags = <HarmFlag>[];

  /// Severity as a ratio against a guideline, uncapped so that a day at three
  /// times the sodium guideline is not recorded as the same as a day at one.
  double ratio(double value, double limit) => limit <= 0 ? 0 : value / limit;

  String pct(double share) => '${(share * 100).round()}%';

  // --- sodium ---
  flags.add(HarmFlag(
    kind: HarmKind.sodium,
    severity: ratio(totals.sodiumMg, HarmLimits.sodiumMg),
    detail: '${totals.sodiumMg.round()} mg of '
        '${HarmLimits.sodiumMg.round()} mg',
  ));

  // --- free sugars ---
  final sugarShare =
      energy <= 0 ? 0.0 : totals.addedSugarG * Atwater.carbs / energy;
  flags.add(HarmFlag(
    kind: HarmKind.addedSugar,
    severity: ratio(sugarShare, HarmLimits.freeSugarShare),
    detail: '${totals.addedSugarG.round()} g — ${pct(sugarShare)} of energy',
  ));

  // --- saturated fat ---
  final satShare = energy <= 0 ? 0.0 : totals.satFatG * Atwater.fat / energy;
  flags.add(HarmFlag(
    kind: HarmKind.saturatedFat,
    severity: ratio(satShare, HarmLimits.satFatShare),
    detail: '${totals.satFatG.round()} g — ${pct(satShare)} of energy',
  ));

  // --- trans fat ---
  final transShare =
      energy <= 0 ? 0.0 : totals.transFatG * Atwater.fat / energy;
  flags.add(HarmFlag(
    kind: HarmKind.transFat,
    severity: ratio(transShare, HarmLimits.transFatShare),
    detail: totals.transFatG <= 0
        ? 'None recorded'
        : '${totals.transFatG.toStringAsFixed(1)} g',
  ));

  // --- alcohol ---
  final units = totals.alcoholG / HarmLimits.gramsPerAlcoholUnit;
  flags.add(HarmFlag(
    kind: HarmKind.alcohol,
    severity: ratio(units, HarmLimits.alcoholUnitsPerDay),
    detail: units <= 0
        ? 'None recorded'
        : '${units.toStringAsFixed(1)} units',
  ));

  // --- ultra-processed ---
  flags.add(HarmFlag(
    kind: HarmKind.ultraProcessed,
    severity:
        ratio(totals.ultraProcessedShare, HarmLimits.ultraProcessedShare),
    detail: '${pct(totals.ultraProcessedShare)} of energy',
  ));

  // --- additives ---
  flags.add(HarmFlag(
    kind: HarmKind.additives,
    severity: ratio(
      totals.additiveCount.toDouble(),
      HarmLimits.additiveCount.toDouble(),
    ),
    detail: totals.additiveCount == 1
        ? '1 additive listed'
        : '${totals.additiveCount} additives listed',
  ));

  return Toxins(flags: _ordered(flags), load: _load(flags));
}

/// The day's harm as a single 0..100 figure.
///
/// Each reading contributes its weight, scaled by severity but capped at
/// **twice** the guideline. Without that cap one catastrophic number — a
/// 6,000 mg sodium day — would saturate the meter on its own and hide
/// everything else; without allowing severity past 1.0 at all, going to three
/// times the sodium guideline would read the same as reaching it.
double _load(List<HarmFlag> flags) {
  var total = 0.0;
  for (final flag in flags) {
    final weight = _weights[flag.kind]!;
    total += weight * flag.severity.clamp(0.0, 2.0) / 2.0;
  }
  return total.clamp(0.0, 100.0);
}

/// Worst first, so the card leads with what actually matters today.
List<HarmFlag> _ordered(List<HarmFlag> flags) {
  final sorted = [...flags]..sort((a, b) {
      final bySeverity = b.severity.compareTo(a.severity);
      if (bySeverity != 0) return bySeverity;
      return a.kind.index.compareTo(b.kind.index);
    });
  return List.unmodifiable(sorted);
}

/// Harm flags for a single food, for the per-food surfaces.
///
/// Measured per 100 g rather than per portion, because this describes the food
/// itself — a Bestiary entry is about what a thing *is*, not about how much of
/// it happened to be eaten once.
Toxins readFoodToxins(FoodPanel food) =>
    readToxins(NutrientTotals.of([Serving(food: food, grams: 100)]));
