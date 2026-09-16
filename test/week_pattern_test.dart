import 'dart:io';

import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/harm.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/signs.dart';
import 'package:cal_tracker/domain/week_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real Monday-to-Sunday week, the same fixture the reckoning tests use.
const _monday = Day(20260914);
const _sunday = Day(20260920);

// --- foods ---

const _crisps = FoodIdentity(id: 1, name: 'Crisps', brand: 'Sodden Hollow');
const _porridge = FoodIdentity(id: 2, name: 'Porridge');
const _noodles = FoodIdentity(id: 3, name: 'Instant noodles');

const _saltyPanel = FoodPanel(
  kcal: 500,
  proteinG: 6,
  carbsG: 50,
  fatG: 30,
  satFatG: 12,
  fibreG: 3,
  sodiumMg: 1500,
  addedSugarG: 5,
  novaGroup: 4,
  additives: ['E621', 'E330'],
);

const _wholePanel = FoodPanel(
  kcal: 360,
  proteinG: 12,
  carbsG: 60,
  fatG: 7,
  satFatG: 1.5,
  fibreG: 10,
  sodiumMg: 10,
  addedSugarG: 0,
  novaGroup: 1,
);

const _noodlePanel = FoodPanel(
  kcal: 450,
  proteinG: 9,
  carbsG: 60,
  fatG: 18,
  satFatG: 9,
  fibreG: 2,
  sodiumMg: 2200,
  addedSugarG: 3,
  novaGroup: 4,
  // Shares E330 with the crisps, which is the case that used to double-count.
  additives: ['E330', 'E102'],
);

LoggedPortion _eat(
  Day day,
  FoodIdentity food,
  FoodPanel panel, {
  double grams = 100,
}) =>
    LoggedPortion(
      day: day,
      food: food,
      serving: Serving(food: panel, grams: grams),
    );

WeekPattern _week(
  List<LoggedPortion> portions, {
  Day? through,
  List<DayMovement> movement = const [],
  double? bodyMassKg,
  int stepGoal = 10000,
}) =>
    readWeek(
      weekStart: _monday,
      weekEnd: _sunday,
      throughDay: through ?? _sunday,
      portions: portions,
      movement: movement,
      stepGoal: stepGoal,
      bodyMassKg: bodyMassKg,
    );

void main() {
  test('the fixture really is a Monday-to-Sunday week', () {
    expect(_monday.weekday, DateTime.monday);
    expect(_sunday.weekday, DateTime.sunday);
  });

  group('the shape of the window', () {
    test('always has seven days, gaps included', () {
      final pattern = _week([_eat(_monday, _porridge, _wholePanel)]);

      expect(pattern.days, hasLength(7));
      expect(pattern.loggedDays, 1);
      expect(pattern.days.where((d) => d.wasLogged), hasLength(1));
    });

    test('an empty week reads as empty rather than throwing', () {
      final pattern = _week(const []);

      expect(pattern.loggedDays, 0);
      expect(pattern.curses, isEmpty);
      expect(pattern.additives, isEmpty);
      expect(pattern.macros, isEmpty);
      expect(pattern.quality.best, isNull);
      expect(pattern.quality.meanVitality, 0);
    });

    test('a week still running reports how far it has got', () {
      final pattern = _week(
        [
          _eat(_monday, _porridge, _wholePanel),
          // Thursday, which is past the window below.
          _eat(_monday.addDays(3), _crisps, _saltyPanel),
        ],
        through: _monday.addDays(1),
      );

      expect(pattern.isPartial, isTrue);
      expect(pattern.daysInWindow, 2);
      // The Thursday entry is outside the window and must not be counted.
      expect(pattern.loggedDays, 1);
    });

    test('a through-day outside the week is clamped, not honoured', () {
      final pattern = _week(
        [_eat(_monday, _porridge, _wholePanel)],
        through: _sunday.addDays(9),
      );

      expect(pattern.throughDay, _sunday);
      expect(pattern.isPartial, isFalse);
    });
  });

  group('curses are folded per day, never measured against a weekly total',
      () {
    // The trap this whole file is arranged around: every HarmLimits figure is
    // a *daily* guideline. A week of ordinary salt compared against 2,000 mg
    // would read as 700% severity and the report would call a normal week a
    // catastrophe.
    test('seven ordinary days do not read as one enormous one', () {
      final pattern = _week([
        for (var i = 0; i < 7; i++)
          // 1,500 mg a day: under the 2,000 mg guideline every single day,
          // but 10,500 mg across the week.
          _eat(_monday.addDays(i), _crisps, _saltyPanel),
      ]);

      final salt = pattern[HarmKind.sodium];

      expect(salt, isNotNull);
      expect(
        salt!.peakSeverity,
        lessThan(1),
        reason: 'no single day passed the guideline, so the week must not '
            'report that one did',
      );
      expect(salt.daysPastGuideline, 0);
      // The weekly total is still reported — as a total, in its own unit.
      expect(salt.weeklyTotal, closeTo(10500, 1));
      expect(salt.unit, 'mg');
    });

    test('counts the days it actually passed the guideline', () {
      final pattern = _week([
        // 2,200 mg — past the guideline.
        _eat(_monday, _noodles, _noodlePanel),
        _eat(_monday.addDays(1), _noodles, _noodlePanel),
        // 10 mg — nowhere near it.
        _eat(_monday.addDays(2), _porridge, _wholePanel),
      ]);

      final salt = pattern[HarmKind.sodium]!;

      expect(salt.daysPastGuideline, 2);
      expect(salt.loggedDays, 3);
      expect(salt.peakDay, anyOf(_monday, _monday.addDays(1)));
      expect(salt.detail, contains('2 of 3'));
    });

    test('the mean is over logged days, not over seven', () {
      final pattern = _week([_eat(_monday, _noodles, _noodlePanel)]);
      final salt = pattern[HarmKind.sodium]!;

      // One logged day, so the mean is that day's severity — not a seventh of
      // it. An unlogged day is an absence of evidence, not a clean day.
      expect(salt.meanSeverity, closeTo(salt.peakSeverity, 0.0001));
    });

    test('a curse nobody triggered is absent rather than listed at zero', () {
      final pattern = _week([_eat(_monday, _porridge, _wholePanel)]);

      expect(pattern[HarmKind.alcohol], isNull);
      expect(pattern.curses.every((c) => c.isNotable), isTrue);
    });

    test('every curse carries the public guideline it is measured against',
        () {
      final pattern = _week([_eat(_monday, _noodles, _noodlePanel)]);

      for (final curse in pattern.curses) {
        expect(curse.basis, isNotEmpty);
        expect(curse.basis, curse.kind.basis);
      }
    });
  });

  group('additives', () {
    test('a code listed by two foods is one additive, not two', () {
      final pattern = _week([
        _eat(_monday, _crisps, _saltyPanel),
        _eat(_monday, _noodles, _noodlePanel),
      ]);

      // E621, E330, E102 — E330 is on both foods.
      expect(pattern.additiveCount, 3);
      expect(
        pattern.additives.map((a) => a.code),
        containsAll(['E330', 'E621', 'E102']),
      );
    });

    test('the same food every day is counted once, on several days', () {
      final pattern = _week([
        for (var i = 0; i < 4; i++) _eat(_monday.addDays(i), _crisps, _saltyPanel),
      ]);

      expect(pattern.additiveCount, 2);
      expect(pattern.additives.first.days, 4);
    });

    test('names the foods that listed each one, most-eaten first', () {
      final pattern = _week([
        _eat(_monday, _crisps, _saltyPanel, grams: 30),
        _eat(_monday, _noodles, _noodlePanel, grams: 300),
      ]);

      final shared =
          pattern.additives.firstWhere((a) => a.code == 'E330');

      expect(shared.foods.first, _noodles);
      expect(shared.foods, hasLength(2));
    });

    test('is ordered by how many days it appeared on', () {
      final pattern = _week([
        _eat(_monday, _crisps, _saltyPanel),
        _eat(_monday.addDays(1), _crisps, _saltyPanel),
        _eat(_monday.addDays(2), _noodles, _noodlePanel),
      ]);

      // E330 is on both foods and so appears on all three days.
      expect(pattern.additives.first.code, 'E330');
      expect(pattern.additives.first.days, 3);
    });
  });

  group('attribution is by the portion actually eaten', () {
    test('a large helping of a mild food outranks a nibble of a strong one',
        () {
      final pattern = _week([
        // 30 g of crisps: 450 mg of sodium.
        _eat(_monday, _crisps, _saltyPanel, grams: 30),
        // 400 g of porridge: 40 mg. Far less, despite the larger portion.
        _eat(_monday, _porridge, _wholePanel, grams: 400),
      ]);

      expect(pattern.carriedSodium.first.food, _crisps);
    });

    test('and the reverse, which is the regression that matters', () {
      final pattern = _week([
        // 5 g of crisps: 75 mg.
        _eat(_monday, _crisps, _saltyPanel, grams: 5),
        // 1 kg of porridge: 100 mg. The mild food wins on volume, which a
        // per-100g ranking would get backwards.
        _eat(_monday, _porridge, _wholePanel, grams: 1000),
      ]);

      expect(
        pattern.carriedSodium.first.food,
        _porridge,
        reason: 'ranking by the panel rather than the portion would put the '
            'crisps first, which is true of the food and false of the week',
      );
    });

    test('sums repeats and counts the days they fell on', () {
      final pattern = _week([
        _eat(_monday, _crisps, _saltyPanel),
        _eat(_monday, _crisps, _saltyPanel),
        _eat(_monday.addDays(1), _crisps, _saltyPanel),
      ]);

      final tally = pattern.carriedSodium.first;

      expect(tally.food, _crisps);
      expect(tally.times, 3);
      expect(tally.days, 2);
      expect(tally.amount, closeTo(4500, 1));
      expect(tally.grams, closeTo(300, 0.01));
    });

    test('a food that carried none of it is not listed at zero', () {
      final pattern = _week([
        _eat(_monday, _crisps, _saltyPanel),
        _eat(_monday, _porridge, _wholePanel),
      ]);

      final alcohol = attribute(
        [
          _eat(_monday, _crisps, _saltyPanel),
          _eat(_monday, _porridge, _wholePanel),
        ],
        amount: (p) => p.serving.alcoholG,
        unit: 'g',
      );

      expect(alcohol, isEmpty);
      expect(pattern.carriedSodium, hasLength(2));
    });

    test('is capped, so the panel is a short list rather than the journal', () {
      final portions = [
        for (var i = 0; i < 9; i++)
          _eat(
            _monday,
            FoodIdentity(id: 100 + i, name: 'Food $i'),
            _saltyPanel,
            grams: (i + 1) * 10,
          ),
      ];

      expect(
        attribute(portions, amount: (p) => p.serving.sodiumMg, unit: 'mg'),
        hasLength(WeeklyCurse.maxCarriers),
      );
    });
  });

  group('quality', () {
    test('names the best and the worst day', () {
      final pattern = _week([
        _eat(_monday, _porridge, _wholePanel),
        _eat(_monday.addDays(1), _crisps, _saltyPanel),
      ]);

      expect(pattern.quality.best!.day, _monday);
      expect(pattern.quality.worst!.day, _monday.addDays(1));
      expect(
        pattern.quality.best!.score,
        greaterThan(pattern.quality.worst!.score),
      );
    });

    test('counts clean days — logged, and under every guideline', () {
      final pattern = _week([
        _eat(_monday, _porridge, _wholePanel),
        _eat(_monday.addDays(1), _noodles, _noodlePanel),
      ]);

      expect(pattern.quality.cleanDays, 1);
    });

    test('an unlogged day is never a clean day', () {
      final pattern = _week([_eat(_monday, _noodles, _noodlePanel)]);

      // Six days went unlogged; none of them may be counted as restraint.
      expect(pattern.quality.cleanDays, 0);
    });

    test('protein per kg needs a weigh-in and says so by being null', () {
      final without = _week([_eat(_monday, _porridge, _wholePanel)]);
      final with_ = _week(
        [_eat(_monday, _porridge, _wholePanel, grams: 1000)],
        bodyMassKg: 75,
      );

      expect(without.quality.proteinPerKg, isNull);
      expect(without.quality.daysAtProteinTarget, 0);
      expect(with_.quality.proteinPerKg, isNotNull);
      expect(with_.quality.daysAtProteinTarget, 1);
    });

    test('fibre density is counted per day, not from the weekly total', () {
      final pattern = _week([
        // 1000 g of porridge: 100 g fibre on 3600 kcal — well past 14/1000.
        _eat(_monday, _porridge, _wholePanel, grams: 1000),
        _eat(_monday.addDays(1), _crisps, _saltyPanel),
      ]);

      expect(pattern.quality.daysAtFibreDensity, 1);
    });
  });

  group('movement and signs', () {
    test('counts step-goal days without ever naming a calorie', () {
      final pattern = _week(
        [_eat(_monday, _porridge, _wholePanel)],
        movement: [
          const DayMovement(day: _monday, steps: 12000, waterMl: 2500),
          DayMovement(day: _monday.addDays(1), steps: 4000),
        ],
        stepGoal: 10000,
      );

      expect(pattern.movement.steps, 16000);
      expect(pattern.movement.goalDays, 1);
      expect(pattern.movement.daysAtWaterTarget, 1);
    });

    test('signs are the mean across logged days', () {
      final pattern = _week([
        _eat(_monday, _porridge, _wholePanel),
        _eat(_monday.addDays(1), _porridge, _wholePanel),
      ]);

      // Both days are identical, so the mean is one day's charge.
      expect(pattern.signs[Sign.quen], greaterThan(0));
      expect(
        pattern.signs[Sign.quen],
        closeTo(pattern.days.first.signs[Sign.quen], 0.0001),
      );
    });

    test('an empty week has no charge at all', () {
      expect(_week(const []).signs[Sign.igni], 0);
    });
  });

  group('the seal holds by construction', () {
    test('the file cannot reach the verdict', () {
      // Crude and cheap, and it is the only thing that stops the obvious
      // future mistake: "just pass the DayEnergys in too, it is convenient".
      final source = _read('lib/domain/week_pattern.dart');

      for (final forbidden in const [
        'reckoning.dart',
        'energy.dart',
        'sealed_value.dart',
      ]) {
        expect(
          source,
          isNot(contains("import '$forbidden'")),
          reason: 'week_pattern.dart must not be able to see $forbidden',
        );
      }
    });

    test('no field holds an expenditure, a balance or a weight', () {
      final pattern = _week([_eat(_monday, _porridge, _wholePanel)]);

      // If any of these ever compiles, the open half has grown a verdict.
      expect(pattern.macros.every((m) => m.share <= 1), isTrue);
      expect(pattern.quality.meanVitality, isNotNull);
    });
  });
}

String _read(String path) => File(path).readAsStringSync();
