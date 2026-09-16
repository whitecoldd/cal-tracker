/// What the week tended towards, said in one line each. Pure Dart.
///
/// A [WeekPattern] is figures; this turns them into statements a person can
/// read. Both directions — what the week carried and what it held — because a
/// report that lists only faults is an accusation, and CLAUDE.md §7 rules that
/// out in substance as well as in wording.
///
/// Three rules govern every statement in this file:
///
/// 1. **Descriptive, never diagnostic.** A finding says what was eaten against
///    a published guideline. It never says what that will do to the person
///    eating it, never names a condition, and never tells them to change
///    anything. There is no *should*, no *try*, no *target for next week*.
/// 2. **Never directional.** Nothing here compares intake to expenditure or to
///    last week. A week-over-week comparison is one subtraction away from a
///    trend statement, which is the verdict.
/// 3. **The guideline travels with the accusation.** Every warning that rests
///    on a public figure carries it in [Finding.basis], the same way
///    `HarmKind.basis` already does on the Alchemy panel.
///
/// [FindingCode] exists so tests assert on an identity rather than on prose.
/// The wording here will be revised; the tests should survive that.
library;

import 'day.dart';
import 'harm.dart';
import 'nutrition.dart';
import 'week_pattern.dart';

/// Which way a finding cuts.
///
/// A judgement of the week, never of the person — see the library doc.
enum Tone { boon, warning }

/// A stable identity for each statement.
enum FindingCode {
  // --- warnings ---
  saltOnMostDays,
  sweetRot,
  thickBlood,
  rancidOil,
  strongDrink,
  refinedMatter,
  residue,
  thinFibre,
  compositionDrift,
  oneHeavyDay,
  theGaps,

  // --- boons ---
  cleanDays,
  fibreHeld,
  proteinHeld,
  wholeFood,
  saltRestraint,
  noStrongDrink,
  sugarLow,
  everyDayWritten,
  steadyHand,
  groundCovered,
  bestDay,
}

/// One descriptive statement about the week.
class Finding {
  const Finding({
    required this.code,
    required this.tone,
    required this.title,
    required this.detail,
    required this.weight,
    this.basis,
  });

  final FindingCode code;
  final Tone tone;

  /// Short and in-world. Upper-cased by the widget, not here.
  final String title;

  /// The figure it rests on.
  final String detail;

  /// The public guideline, verbatim, where there is one.
  final String? basis;

  /// Ordering key, 0..1. Never shown.
  final double weight;
}

/// At most this many of each tone reach the screen or the prompt.
const int maxFindingsPerTone = 3;

/// Every statement the week supports. Unsorted, uncapped.
List<Finding> readFindings(WeekPattern pattern) {
  if (pattern.loggedDays == 0) return const [];

  return [
    ..._warnings(pattern),
    ..._boons(pattern),
  ];
}

/// The ones worth showing, sorted by weight and capped.
///
/// Capped **per tone** rather than overall. A single sorted list would let one
/// tone take every slot, which is how a report becomes either a scolding or a
/// flattery — and the user asked for both halves.
List<Finding> topFindings(
  List<Finding> all,
  Tone tone, {
  int limit = maxFindingsPerTone,
}) {
  final matching = all.where((f) => f.tone == tone).toList()
    ..sort((a, b) {
      final byWeight = b.weight.compareTo(a.weight);
      if (byWeight != 0) return byWeight;
      // Stable, so a fixture does not reorder between runs.
      return a.code.index.compareTo(b.code.index);
    });

  return List.unmodifiable(matching.take(limit));
}

// --- warnings ---

List<Finding> _warnings(WeekPattern pattern) {
  final found = <Finding>[];
  final logged = pattern.loggedDays;

  void add(
    FindingCode code,
    String title,
    String detail,
    double weight, {
    String? basis,
  }) =>
      found.add(
        Finding(
          code: code,
          tone: Tone.warning,
          title: title,
          detail: detail,
          weight: weight.clamp(0.0, 1.0),
          basis: basis,
        ),
      );

  // Salt, sugar, saturated fat: the three that are about how often.
  for (final (kind, code, title) in const [
    (HarmKind.sodium, FindingCode.saltOnMostDays, 'Salt on most days'),
    (HarmKind.addedSugar, FindingCode.sweetRot, 'Sweet rot'),
    (HarmKind.saturatedFat, FindingCode.thickBlood, 'Thick blood'),
  ]) {
    final curse = pattern[kind];
    if (curse == null) continue;

    final past = curse.daysPastGuideline;
    final threshold = kind == HarmKind.sodium ? (logged + 1) ~/ 2 : 2;
    if (past < threshold || past == 0) continue;

    add(
      code,
      title,
      '${_days(past)} of $logged logged past the guideline'
      '${_peak(curse)}.',
      past / logged,
      basis: curse.basis,
    );
  }

  // Trans fat is different in kind: the WHO position is elimination, so any
  // amount at all is worth one line, and it leads.
  final trans = pattern[HarmKind.transFat];
  if (trans != null && (trans.weeklyTotal ?? 0) > 0) {
    add(
      FindingCode.rancidOil,
      'Rancid oil',
      '${_grams(trans.weeklyTotal!)} across the week, on '
      '${_days(trans.daysNotable)} of $logged logged.',
      0.95,
      basis: trans.basis,
    );
  }

  final drink = pattern[HarmKind.alcohol];
  if (drink != null && (drink.weeklyTotal ?? 0) > 0) {
    final units = drink.weeklyTotal!;
    add(
      FindingCode.strongDrink,
      'Strong drink',
      '${units.toStringAsFixed(1)} units across '
      '${_days(drink.daysNotable)} of $logged logged.',
      (units / 14).clamp(0.0, 1.0),
      basis: drink.basis,
    );
  }

  if (pattern.quality.ultraProcessedShare >= HarmLimits.ultraProcessedShare) {
    add(
      FindingCode.refinedMatter,
      'Refined matter',
      '${_percent(pattern.quality.ultraProcessedShare)} of the week’s '
      'energy came from ultra-processed food.',
      pattern.quality.ultraProcessedShare,
      basis: HarmKind.ultraProcessed.basis,
    );
  }

  if (pattern.additiveCount >= HarmLimits.additiveCount) {
    final worst = pattern.additives.first;
    add(
      FindingCode.residue,
      'Alchemical residue',
      '${pattern.additiveCount} distinct additives across the week. '
      '${worst.code} appeared on ${_days(worst.days)}.',
      (pattern.additiveCount / 20).clamp(0.0, 1.0),
      basis: HarmKind.additives.basis,
    );
  }

  final thin = logged - pattern.quality.daysAtFibreDensity;
  if (thin >= 4 && logged >= 4) {
    add(
      FindingCode.thinFibre,
      'Thin fibre',
      '${_days(thin)} of $logged logged under '
      '${fibreTargetPer1000Kcal.round()} g per 1000 kcal, averaging '
      '${pattern.quality.meanFibrePer1000Kcal.toStringAsFixed(1)}.',
      thin / logged,
    );
  }

  for (final macro in pattern.macros) {
    if (macro.isInRange) continue;
    add(
      FindingCode.compositionDrift,
      '${macro.label} ran ${macro.isBelowRange ? 'low' : 'high'}',
      '${_percent(macro.share)} of the week’s energy, against the usual '
      '${_percent(macro.rangeLow)}–${_percent(macro.rangeHigh)}.',
      0.4,
      basis: 'The usual range a diet falls in, not a target set for you.',
    );
  }

  final heavy = _oneHeavyDay(pattern);
  if (heavy != null) {
    add(
      FindingCode.oneHeavyDay,
      'One heavy day',
      '${_weekday(heavy)} carried more than twice what the rest of the week '
      'did.',
      0.5,
    );
  }

  if (logged < 4) {
    add(
      FindingCode.theGaps,
      'The gaps',
      '$logged of 7 days written down. Everything here rests on those '
      '${_days(logged)}.',
      0.6,
    );
  }

  return found;
}

// --- boons ---

List<Finding> _boons(WeekPattern pattern) {
  final found = <Finding>[];
  final logged = pattern.loggedDays;
  final quality = pattern.quality;

  void add(FindingCode code, String title, String detail, double weight) =>
      found.add(
        Finding(
          code: code,
          tone: Tone.boon,
          title: title,
          detail: detail,
          weight: weight.clamp(0.0, 1.0),
        ),
      );

  if (quality.cleanDays >= 2) {
    add(
      FindingCode.cleanDays,
      'Clean days',
      '${_days(quality.cleanDays)} of $logged logged passed every guideline.',
      quality.cleanDays / logged,
    );
  }

  if (quality.daysAtFibreDensity >= 3) {
    add(
      FindingCode.fibreHeld,
      'Quen held',
      '${_days(quality.daysAtFibreDensity)} of $logged logged at or past '
      '${fibreTargetPer1000Kcal.round()} g of fibre per 1000 kcal.',
      quality.daysAtFibreDensity / logged,
    );
  }

  if (quality.daysAtProteinTarget >= 3) {
    add(
      FindingCode.proteinHeld,
      'Igni held',
      '${_days(quality.daysAtProteinTarget)} of $logged logged at or past '
      '$proteinTargetPerKg g of protein per kg.',
      quality.daysAtProteinTarget / logged,
    );
  }

  if (quality.wholeFoodShare >= 0.40) {
    add(
      FindingCode.wholeFood,
      'Whole food',
      '${_percent(quality.wholeFoodShare)} of the week’s energy came '
      'from unprocessed or minimally processed food.',
      quality.wholeFoodShare,
    );
  }

  final salt = pattern[HarmKind.sodium];
  if (salt == null || salt.daysPastGuideline == 0) {
    add(
      FindingCode.saltRestraint,
      'Salt held',
      'Under ${HarmLimits.sodiumMg.round()} mg on every one of the '
      '${_days(logged)} written down.',
      0.9,
    );
  }

  final drink = pattern[HarmKind.alcohol];
  if (drink == null || (drink.weeklyTotal ?? 0) <= 0) {
    add(
      FindingCode.noStrongDrink,
      'No strong drink',
      'Nothing alcoholic was written down all week.',
      0.3,
    );
  }

  final sugar = pattern[HarmKind.addedSugar];
  if (sugar == null || (sugar.daysPastGuideline == 0 &&
      sugar.meanSeverity < 0.5)) {
    add(
      FindingCode.sugarLow,
      'Sweet rot kept out',
      'Free sugars stayed well under a tenth of the week’s energy.',
      0.8,
    );
  }

  if (logged >= 7) {
    add(
      FindingCode.everyDayWritten,
      'Every day written',
      'Seven of seven. The figures here rest on a whole week.',
      0.85,
    );
  }

  final steady = _vitalityRange(pattern);
  if (steady != null && steady < 20 && logged >= 3) {
    add(
      FindingCode.steadyHand,
      'A steady hand',
      'The best and the worst day were ${steady.round()} points apart.',
      0.5,
    );
  }

  if (pattern.movement.goalDays >= 4) {
    add(
      FindingCode.groundCovered,
      'Aard held',
      '${_days(pattern.movement.goalDays)} at or past the step goal.',
      pattern.movement.goalDays / 7,
    );
  }

  final best = quality.best;
  if (best != null && best.score > 0) {
    add(
      FindingCode.bestDay,
      'The best of them',
      '${_weekday(best.day)} scored ${best.score.round()} for what it was '
      'made of.',
      0.45,
    );
  }

  return found;
}

// --- helpers ---

/// The day whose harm load was more than twice the rest of the week's mean.
Day? _oneHeavyDay(WeekPattern pattern) {
  final logged = pattern.days.where((d) => d.wasLogged).toList();
  if (logged.length < 3) return null;

  for (final day in logged) {
    final others = logged.where((d) => d.day != day.day).toList();
    final mean =
        others.fold<double>(0, (sum, d) => sum + d.toxins.load) / others.length;

    // A floor, so a near-zero week does not report a "heavy" day over noise.
    if (mean >= 5 && day.toxins.load >= mean * 2) return day.day;
  }

  return null;
}

/// How far apart the best and worst logged days scored.
double? _vitalityRange(WeekPattern pattern) {
  final best = pattern.quality.best;
  final worst = pattern.quality.worst;
  if (best == null || worst == null) return null;
  return best.score - worst.score;
}

String _days(int n) => '$n ${n == 1 ? 'day' : 'days'}';

String _percent(double share) => '${(share * 100).round()}%';

String _grams(double g) =>
    g >= 10 ? '${g.round()} g' : '${g.toStringAsFixed(1)} g';

String _peak(WeeklyCurse curse) {
  final day = curse.peakDay;
  return day == null ? '' : ', worst on ${_weekday(day)}';
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _weekday(Day day) => _weekdayNames[day.weekday - 1];
