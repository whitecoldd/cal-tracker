/// What a week was made of. Pure Dart.
///
/// This is the **open half** of the Reckoning: readable on any day of the
/// week, because nothing in it answers "am I losing or gaining weight?".
///
/// The seal is enforced structurally rather than by a gate. There is no
/// [SealedValue] in this file, no import of `reckoning.dart`, `energy.dart` or
/// `sealed_value.dart`, and — the load-bearing part — **no field anywhere in
/// here holds a quantity of energy eaten, an expenditure, or a weight.** A
/// widget cannot render a verdict from this type because the type has nowhere
/// to put one. That is stronger than gating, which a widget can get wrong.
///
/// Composition, harm, fibre density, additives and movement are all things the
/// Journal and Alchemy screens already show every day (CLAUDE.md §1), so
/// aggregating them across a week reveals nothing new about direction.
///
/// One rule matters more than the rest, and it is easy to get wrong:
/// **every figure in [HarmLimits] is a *daily* guideline.** A week's sodium
/// measured against 2,000 mg would read as 700% severity. So curses are
/// computed per day and then folded; only composition uses a week-wide total.
/// See [readWeek] and the test that asserts it.
library;

import 'day.dart';
import 'harm.dart';
import 'nutrition.dart';
import 'scoring.dart';
import 'signs.dart';

/// Which food a portion was, for the surfaces that have to name it.
///
/// An id and two strings — nothing drift-shaped. `domain/` never learns that a
/// `Food` row exists; the adapter in `data/` builds these.
///
/// [Serving] deliberately stays anonymous: it is used by every screen and a
/// required name would break every fixture in the suite. Identity rides
/// alongside it instead of inside it.
class FoodIdentity {
  const FoodIdentity({required this.id, required this.name, this.brand});

  final int id;
  final String name;
  final String? brand;

  String get label =>
      (brand == null || brand!.isEmpty) ? name : '$name — $brand';

  @override
  bool operator ==(Object other) => other is FoodIdentity && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FoodIdentity($id, $name)';
}

/// One entry: what, how much, which day.
class LoggedPortion {
  const LoggedPortion({
    required this.day,
    required this.food,
    required this.serving,
  });

  final Day day;
  final FoodIdentity food;
  final Serving serving;

  FoodPanel get panel => serving.food;
  double get grams => serving.grams;
}

/// What was measured about a day other than the food.
///
/// Steps and water are shown daily on the Journal and The Path, so they are
/// open like the rest of this file. Active kilocalories are **not** here, and
/// must not be added: expenditure is half of the verdict.
class DayMovement {
  const DayMovement({
    required this.day,
    this.steps = 0,
    this.distanceM = 0,
    this.waterMl = 0,
    this.mealSlotsUsed = 0,
  });

  final Day day;
  final int steps;
  final double distanceM;
  final int waterMl;

  /// How many distinct meal slots were used — the spread term in Yrden.
  ///
  /// An `int` rather than the `MealSlot` enum, which lives in `data/tables.
  /// dart`: importing it here would drag drift into `domain/` for a count.
  final int mealSlotsUsed;
}

/// One day, read exactly the way the Alchemy screen reads it.
class DayPattern {
  const DayPattern({
    required this.day,
    required this.totals,
    required this.toxins,
    required this.vitality,
    required this.signs,
    required this.movement,
  });

  final Day day;
  final NutrientTotals totals;
  final Toxins toxins;
  final Vitality vitality;
  final SignCharges signs;
  final DayMovement movement;

  bool get wasLogged => !totals.isEmpty;

  /// Whether the day stayed under every guideline.
  ///
  /// Measured against the guideline, **not** against
  /// [HarmFlag.notableSeverity]. That threshold is a twentieth of the
  /// guideline — it exists to keep trace readings off the Alchemy panel — so a
  /// day with nothing notable on it would mean a day that had eaten almost
  /// nothing. A bowl of porridge trips "thick blood" at 38% of the saturated
  /// fat guideline, and calling that day unclean would make the count useless
  /// and the boon unearnable.
  bool get isClean =>
      wasLogged && toxins.flags.every((flag) => flag.severity < 1);
}

/// A food's contribution to one quantity across the week.
///
/// **By the portion actually eaten**, never per 100 g. A food eaten in 500 g
/// helpings outranks a saltier one eaten by the teaspoon, and saying otherwise
/// would be a true statement about the food and a false one about the week.
class FoodTally {
  const FoodTally({
    required this.food,
    required this.amount,
    required this.unit,
    required this.grams,
    required this.times,
    required this.days,
  });

  final FoodIdentity food;

  /// mg, g, units or kcal, per [unit].
  final double amount;
  final String unit;

  /// Total grams of it eaten across the week.
  final double grams;

  /// How many entries, and on how many distinct days.
  final int times;
  final int days;
}

/// One harm, read across the week instead of across a day.
class WeeklyCurse {
  const WeeklyCurse({
    required this.kind,
    required this.daysNotable,
    required this.daysPastGuideline,
    required this.loggedDays,
    required this.peakSeverity,
    required this.meanSeverity,
    required this.peakDay,
    required this.weeklyTotal,
    required this.unit,
    required this.detail,
    required this.carriers,
  });

  final HarmKind kind;

  /// Days on which the reading was worth showing at all.
  final int daysNotable;

  /// Days on which it reached or passed the guideline.
  final int daysPastGuideline;

  /// The denominator for both, so "3 of 4" never reads as "3 of 7".
  final int loggedDays;

  final double peakSeverity;

  /// Mean severity over **logged** days, not over seven. An unlogged day is an
  /// absence of evidence, not a clean day.
  final double meanSeverity;

  final Day? peakDay;

  /// The week's total, where the quantity adds up. Null for
  /// [HarmKind.ultraProcessed], which is a share of energy rather than an
  /// amount of anything.
  final double? weeklyTotal;
  final String unit;

  /// The figure in words, the way [HarmFlag.detail] is. Descriptive only.
  final String detail;

  /// Which foods carried it, most first.
  final List<FoodTally> carriers;

  bool get isNotable => daysNotable > 0;

  /// The guideline this is measured against, verbatim.
  String get basis => kind.basis;

  static const int maxCarriers = 3;
}

/// One E-number, and where in the week it came from.
class AdditiveTally {
  const AdditiveTally({
    required this.code,
    required this.days,
    required this.foods,
  });

  /// Normalised — `E150d`. See [additiveCode].
  final String code;

  /// Distinct days it appeared on.
  final int days;

  /// The foods that listed it, most-eaten first.
  final List<FoodIdentity> foods;

  static const int maxFoods = 3;
}

/// A day and what it scored, for naming the best and the worst.
class DayScore {
  const DayScore({required this.day, required this.score});

  final Day day;
  final double score;
}

/// What the week did well, in figures.
///
/// Every one of these is a count of days or a share of the week's own energy.
/// None is a comparison against expenditure, and none can be rearranged into
/// one.
class WeekQuality {
  const WeekQuality({
    required this.meanVitality,
    required this.meanToxicity,
    required this.best,
    required this.worst,
    required this.daysAtFibreDensity,
    required this.daysAtProteinTarget,
    required this.cleanDays,
    required this.meanFibrePer1000Kcal,
    required this.proteinPerKg,
    required this.wholeFoodShare,
    required this.ultraProcessedShare,
    required this.averageGlycemicIndex,
  });

  static const empty = WeekQuality(
    meanVitality: 0,
    meanToxicity: 0,
    best: null,
    worst: null,
    daysAtFibreDensity: 0,
    daysAtProteinTarget: 0,
    cleanDays: 0,
    meanFibrePer1000Kcal: 0,
    proteinPerKg: null,
    wholeFoodShare: 0,
    ultraProcessedShare: 0,
    averageGlycemicIndex: null,
  );

  final double meanVitality;
  final double meanToxicity;

  final DayScore? best;
  final DayScore? worst;

  /// Days at or past 14 g of fibre per 1000 kcal.
  final int daysAtFibreDensity;

  /// Days at or past 1.6 g of protein per kg. Zero with no weigh-in, since
  /// the measure cannot be taken at all.
  final int daysAtProteinTarget;

  /// Days that passed no guideline at all. See [DayPattern.isClean].
  final int cleanDays;

  final double meanFibrePer1000Kcal;

  /// Weekly mean protein per kg of body mass. Null with no weigh-in.
  ///
  /// Body mass is used here the same way [scoreVitality] already uses it.
  /// Weight is logged and shown every day; only its *interpretation* is
  /// sealed (CLAUDE.md §1), so a protein-adequacy figure derived from it is
  /// not a leak and must not be "fixed" into one.
  final double? proteinPerKg;

  final double wholeFoodShare;
  final double ultraProcessedShare;
  final double? averageGlycemicIndex;
}

/// The week's movement, as behaviour rather than as energy.
class WeekMovement {
  const WeekMovement({
    required this.steps,
    required this.goalDays,
    required this.distanceM,
    required this.waterMl,
    required this.daysAtWaterTarget,
  });

  static const empty = WeekMovement(
    steps: 0,
    goalDays: 0,
    distanceM: 0,
    waterMl: 0,
    daysAtWaterTarget: 0,
  );

  final int steps;

  /// Days that met the step goal. A count of days, deliberately — active
  /// kilocalories belong to the verdict and are not in this file.
  final int goalDays;

  final double distanceM;
  final int waterMl;
  final int daysAtWaterTarget;
}

/// What the week was made of. Readable on **any** day.
class WeekPattern {
  const WeekPattern({
    required this.weekStart,
    required this.weekEnd,
    required this.throughDay,
    required this.days,
    required this.macros,
    required this.curses,
    required this.additives,
    required this.quality,
    required this.movement,
    required this.signs,
    required this.carriedSodium,
    required this.carriedFreeSugar,
    required this.carriedSatFat,
    required this.carriedAdditives,
  });

  final Day weekStart;
  final Day weekEnd;

  /// The last day included: today for a week in progress, [weekEnd] for a
  /// finished one.
  final Day throughDay;

  /// Seven entries, oldest first. Unlogged days are present and empty, so the
  /// shape of the week includes its gaps.
  final List<DayPattern> days;

  /// Composition across the window. Shares of the week's own macro energy —
  /// no quantity of energy appears in a [MacroShare] except grams of each
  /// macro, which is what the Alchemy vials already show daily.
  final List<MacroShare> macros;

  /// Notable curses, worst first.
  final List<WeeklyCurse> curses;

  /// Distinct E-numbers, most days first.
  final List<AdditiveTally> additives;

  final WeekQuality quality;
  final WeekMovement movement;

  /// The weekly mean of each day's Sign charges.
  final SignCharges signs;

  final List<FoodTally> carriedSodium;
  final List<FoodTally> carriedFreeSugar;
  final List<FoodTally> carriedSatFat;
  final List<FoodTally> carriedAdditives;

  /// Whether the week is still running.
  bool get isPartial => throughDay.value < weekEnd.value;

  int get loggedDays => days.where((d) => d.wasLogged).length;

  /// Days elapsed in the window so far, 1..7.
  int get daysInWindow => weekStart.daysUntil(throughDay) + 1;

  /// The distinct additive codes across the whole week.
  int get additiveCount => additives.length;

  WeeklyCurse? operator [](HarmKind kind) {
    for (final curse in curses) {
      if (curse.kind == kind) return curse;
    }
    return null;
  }
}

/// Reads a week from its entries. Pure: no clock, no database, no gate.
///
/// [throughDay] is the last day to include, and is clamped into
/// [weekStart]..[weekEnd] here so a caller cannot widen the window by mistake.
WeekPattern readWeek({
  required Day weekStart,
  required Day weekEnd,
  required Day throughDay,
  required Iterable<LoggedPortion> portions,
  Iterable<DayMovement> movement = const [],
  int stepGoal = 10000,
  double? bodyMassKg,
}) {
  final through = _clampDay(throughDay, weekStart, weekEnd);

  final byDay = <int, List<LoggedPortion>>{};
  for (final portion in portions) {
    if (portion.day.value < weekStart.value) continue;
    if (portion.day.value > through.value) continue;
    byDay.putIfAbsent(portion.day.value, () => []).add(portion);
  }

  final movementByDay = {for (final m in movement) m.day.value: m};

  final loggedInWeek = byDay.values.where((p) => p.isNotEmpty).length;

  // --- day by day, because every guideline is a daily one ---
  final days = <DayPattern>[];
  for (var i = 0; i < 7; i++) {
    final day = weekStart.addDays(i);
    final portionsToday = byDay[day.value] ?? const <LoggedPortion>[];
    final totals = NutrientTotals.of([
      for (final p in portionsToday) p.serving,
    ]);
    final vitality = scoreVitality(totals, bodyMassKg: bodyMassKg);
    final today = movementByDay[day.value] ?? DayMovement(day: day);

    days.add(
      DayPattern(
        day: day,
        totals: totals,
        toxins: readToxins(totals),
        vitality: vitality,
        signs: chargeSigns(
          totals: totals,
          vitality: vitality,
          steps: today.steps,
          distanceM: today.distanceM,
          stepGoal: stepGoal,
          loggedDaysInWeek: loggedInWeek,
          waterMl: today.waterMl,
          mealSlotsUsed: today.mealSlotsUsed,
        ),
        movement: today,
      ),
    );
  }

  final logged = days.where((d) => d.wasLogged).toList(growable: false);
  final inWindow = [
    for (final portion in byDay.values) ...portion,
  ];

  // The only week-wide total, and it is used for composition alone. Never
  // pass this to `readToxins` — see the library doc.
  final weekTotals = NutrientTotals.of([
    for (final p in inWindow) p.serving,
  ]);

  return WeekPattern(
    weekStart: weekStart,
    weekEnd: weekEnd,
    throughDay: through,
    days: List.unmodifiable(days),
    macros: macroShares(weekTotals),
    curses: _curses(days: days, logged: logged, portions: inWindow),
    additives: _additives(inWindow),
    quality: _quality(
      logged: logged,
      weekTotals: weekTotals,
      bodyMassKg: bodyMassKg,
    ),
    movement: _movement(days: days, stepGoal: stepGoal),
    signs: _meanSigns(logged),
    carriedSodium: attribute(
      inWindow,
      amount: (p) => p.serving.sodiumMg,
      unit: 'mg',
    ),
    carriedFreeSugar: attribute(
      inWindow,
      amount: (p) => p.serving.addedSugarG ?? 0,
      unit: 'g',
    ),
    carriedSatFat: attribute(
      inWindow,
      amount: (p) => p.serving.satFatG,
      unit: 'g',
    ),
    carriedAdditives: attribute(
      inWindow,
      // Not scaled by portion: a food lists the additives it lists, however
      // much of it was eaten.
      amount: (p) => p.panel.additives.length.toDouble(),
      unit: 'listed',
    ),
  );
}

/// Ranks foods by how much of one quantity they carried, by actual portion.
///
/// Foods contributing nothing are dropped rather than listed with a zero.
List<FoodTally> attribute(
  Iterable<LoggedPortion> portions, {
  required double Function(LoggedPortion) amount,
  required String unit,
  int limit = WeeklyCurse.maxCarriers,
}) {
  final amounts = <FoodIdentity, double>{};
  final grams = <FoodIdentity, double>{};
  final times = <FoodIdentity, int>{};
  final days = <FoodIdentity, Set<int>>{};

  for (final portion in portions) {
    final value = amount(portion);
    if (value <= 0) continue;

    final food = portion.food;
    amounts[food] = (amounts[food] ?? 0) + value;
    grams[food] = (grams[food] ?? 0) + portion.grams;
    times[food] = (times[food] ?? 0) + 1;
    (days[food] ??= <int>{}).add(portion.day.value);
  }

  final ranked = amounts.keys.toList()
    ..sort((a, b) {
      final byAmount = amounts[b]!.compareTo(amounts[a]!);
      if (byAmount != 0) return byAmount;
      // A stable tiebreak, so a fixture does not reorder between runs.
      return a.id.compareTo(b.id);
    });

  return [
    for (final food in ranked.take(limit))
      FoodTally(
        food: food,
        amount: amounts[food]!,
        unit: unit,
        grams: grams[food] ?? 0,
        times: times[food] ?? 0,
        days: days[food]?.length ?? 0,
      ),
  ];
}

// --- the folds ---

List<WeeklyCurse> _curses({
  required List<DayPattern> days,
  required List<DayPattern> logged,
  required List<LoggedPortion> portions,
}) {
  if (logged.isEmpty) return const [];

  final curses = <WeeklyCurse>[];

  for (final kind in HarmKind.values) {
    var notable = 0;
    var past = 0;
    var peak = 0.0;
    var sum = 0.0;
    Day? peakDay;

    for (final day in logged) {
      final flag = day.toxins[kind];
      if (flag == null) continue;

      sum += flag.severity;
      if (flag.isNotable) notable++;
      if (flag.severity >= 1) past++;
      if (flag.severity > peak) {
        peak = flag.severity;
        peakDay = day.day;
      }
    }

    if (notable == 0) continue;

    final (total, unit) = _weeklyTotal(kind, portions);

    curses.add(
      WeeklyCurse(
        kind: kind,
        daysNotable: notable,
        daysPastGuideline: past,
        loggedDays: logged.length,
        peakSeverity: peak,
        meanSeverity: sum / logged.length,
        peakDay: peakDay,
        weeklyTotal: total,
        unit: unit,
        detail: _curseDetail(
          kind: kind,
          notable: notable,
          past: past,
          logged: logged.length,
          total: total,
          unit: unit,
        ),
        carriers: attribute(
          portions,
          amount: _amountFor(kind),
          unit: unit,
        ),
      ),
    );
  }

  curses.sort((a, b) {
    final byDays = b.daysPastGuideline.compareTo(a.daysPastGuideline);
    if (byDays != 0) return byDays;
    final bySeverity = b.meanSeverity.compareTo(a.meanSeverity);
    if (bySeverity != 0) return bySeverity;
    return a.kind.index.compareTo(b.kind.index);
  });

  return List.unmodifiable(curses);
}

double Function(LoggedPortion) _amountFor(HarmKind kind) => switch (kind) {
      HarmKind.sodium => (p) => p.serving.sodiumMg,
      HarmKind.addedSugar => (p) => p.serving.addedSugarG ?? 0,
      HarmKind.saturatedFat => (p) => p.serving.satFatG,
      HarmKind.transFat => (p) => p.serving.transFatG ?? 0,
      HarmKind.alcohol => (p) => p.serving.alcoholG,
      HarmKind.ultraProcessed => (p) =>
          p.panel.isUltraProcessed ? p.serving.kcal : 0,
      HarmKind.additives => (p) => p.panel.additives.length.toDouble(),
    };

(double?, String) _weeklyTotal(HarmKind kind, List<LoggedPortion> portions) {
  double sum(double Function(LoggedPortion) of) =>
      portions.fold<double>(0, (total, p) => total + of(p));

  return switch (kind) {
    HarmKind.sodium => (sum((p) => p.serving.sodiumMg), 'mg'),
    HarmKind.addedSugar => (sum((p) => p.serving.addedSugarG ?? 0), 'g'),
    HarmKind.saturatedFat => (sum((p) => p.serving.satFatG), 'g'),
    HarmKind.transFat => (sum((p) => p.serving.transFatG ?? 0), 'g'),
    HarmKind.alcohol => (
        sum((p) => p.serving.alcoholG) / HarmLimits.gramsPerAlcoholUnit,
        'units',
      ),
    HarmKind.additives => (
        {for (final p in portions) ...p.panel.additives}.length.toDouble(),
        'listed',
      ),
    // A share of energy, not an amount of anything. Summing it would produce a
    // number with no meaning.
    HarmKind.ultraProcessed => (null, ''),
  };
}

/// The week's reading in words. Descriptive, never diagnostic — CLAUDE.md §7.
String _curseDetail({
  required HarmKind kind,
  required int notable,
  required int past,
  required int logged,
  required double? total,
  required String unit,
}) {
  final days = past == 1 ? 'day' : 'days';

  final head = past > 0
      ? 'Past the guideline on $past of $logged logged $days'
      : 'Noted on $notable of $logged logged '
          '${notable == 1 ? 'day' : 'days'}, under the guideline';

  if (total == null) return '$head.';

  if (kind == HarmKind.additives) {
    final n = total.round();
    return '$head. $n distinct ${n == 1 ? 'additive' : 'additives'} '
        'across the week.';
  }

  return '$head. ${formatAmount(total)} $unit across the week.';
}

/// A figure with thousands separated, and no false precision.
///
/// A week of sodium runs to five digits, and `13614 mg` is a number a person
/// has to count the columns of before they can read it.
String formatAmount(double value) {
  if (value < 100) return value.toStringAsFixed(1);

  final digits = value.round().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return buffer.toString();
}

List<AdditiveTally> _additives(List<LoggedPortion> portions) {
  final days = <String, Set<int>>{};
  final foods = <String, Map<FoodIdentity, double>>{};

  for (final portion in portions) {
    for (final code in portion.panel.additives) {
      (days[code] ??= <int>{}).add(portion.day.value);
      final byFood = foods[code] ??= <FoodIdentity, double>{};
      byFood[portion.food] = (byFood[portion.food] ?? 0) + portion.grams;
    }
  }

  final codes = days.keys.toList()
    ..sort((a, b) {
      final byDays = days[b]!.length.compareTo(days[a]!.length);
      if (byDays != 0) return byDays;
      return a.compareTo(b);
    });

  return List.unmodifiable([
    for (final code in codes)
      AdditiveTally(
        code: code,
        days: days[code]!.length,
        foods: [
          for (final entry in (foods[code]!.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(AdditiveTally.maxFoods))
            entry.key,
        ],
      ),
  ]);
}

WeekQuality _quality({
  required List<DayPattern> logged,
  required NutrientTotals weekTotals,
  required double? bodyMassKg,
}) {
  if (logged.isEmpty) return WeekQuality.empty;

  var vitalitySum = 0.0;
  var toxicitySum = 0.0;
  var fibreDensitySum = 0.0;
  var atFibre = 0;
  var atProtein = 0;
  var clean = 0;

  DayScore? best;
  DayScore? worst;

  for (final day in logged) {
    vitalitySum += day.vitality.score;
    toxicitySum += day.toxins.load;
    fibreDensitySum += day.totals.fibrePer1000Kcal;

    if (day.totals.fibrePer1000Kcal >= fibreTargetPer1000Kcal) atFibre++;
    if (day.isClean) clean++;

    final perKg = proteinPerKg(day.totals, bodyMassKg);
    if (perKg != null && perKg >= proteinTargetPerKg) atProtein++;

    if (best == null || day.vitality.score > best.score) {
      best = DayScore(day: day.day, score: day.vitality.score);
    }
    if (worst == null || day.vitality.score < worst.score) {
      worst = DayScore(day: day.day, score: day.vitality.score);
    }
  }

  final n = logged.length;

  return WeekQuality(
    meanVitality: vitalitySum / n,
    meanToxicity: toxicitySum / n,
    best: best,
    worst: worst,
    daysAtFibreDensity: atFibre,
    daysAtProteinTarget: atProtein,
    cleanDays: clean,
    meanFibrePer1000Kcal: fibreDensitySum / n,
    // Per logged day, so a four-day week is not divided by seven.
    proteinPerKg: bodyMassKg == null || bodyMassKg <= 0
        ? null
        : weekTotals.proteinG / n / bodyMassKg,
    wholeFoodShare: weekTotals.wholeFoodShare,
    ultraProcessedShare: weekTotals.ultraProcessedShare,
    averageGlycemicIndex: weekTotals.averageGlycemicIndex,
  );
}

WeekMovement _movement({
  required List<DayPattern> days,
  required int stepGoal,
}) {
  var steps = 0;
  var goalDays = 0;
  var distance = 0.0;
  var water = 0;
  var atWater = 0;

  for (final day in days) {
    final m = day.movement;
    steps += m.steps;
    distance += m.distanceM;
    water += m.waterMl;
    if (m.steps >= stepGoal && stepGoal > 0) goalDays++;
    if (m.waterMl >= waterTargetMl) atWater++;
  }

  return WeekMovement(
    steps: steps,
    goalDays: goalDays,
    distanceM: distance,
    waterMl: water,
    daysAtWaterTarget: atWater,
  );
}

/// The weekly mean of each Sign's daily charge.
///
/// Axii's consistency term is `loggedDaysInWeek / 7`, which is the same on
/// every day of a given week — so its mean varies only by the glycemic
/// steadiness term. That is coherent rather than a double-count, and worth
/// the sentence so nobody "fixes" it.
SignCharges _meanSigns(List<DayPattern> logged) {
  if (logged.isEmpty) return SignCharges.empty;

  return SignCharges({
    for (final sign in Sign.values)
      sign: logged.fold<double>(0, (sum, d) => sum + d.signs[sign]) /
          logged.length,
  });
}

Day _clampDay(Day day, Day low, Day high) {
  if (day.value < low.value) return low;
  if (day.value > high.value) return high;
  return day;
}
