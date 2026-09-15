import 'package:cal_tracker/domain/hydration.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/scoring.dart';
import 'package:cal_tracker/domain/signs.dart';
import 'package:flutter_test/flutter_test.dart';

/// A whole-food day: fibre-rich, decent protein.
const _lentils = FoodPanel(
  kcal: 350,
  proteinG: 25,
  carbsG: 60,
  sugarG: 2,
  addedSugarG: 0,
  fatG: 1,
  fibreG: 30,
  sodiumMg: 6,
  glycemicIndex: 32,
  novaGroup: 1,
);

/// A NOVA-4 day with a heavy glycemic load.
const _candy = FoodPanel(
  kcal: 400,
  carbsG: 100,
  sugarG: 90,
  addedSugarG: 90,
  fibreG: 0,
  sodiumMg: 50,
  glycemicIndex: 80,
  novaGroup: 4,
);

NutrientTotals _day(FoodPanel panel, {double grams = 100}) =>
    NutrientTotals.of([Serving(food: panel, grams: grams)]);

SignCharges _charge(
  FoodPanel panel, {
  double grams = 100,
  int steps = 0,
  double distanceM = 0,
  int loggedDays = 0,
  int waterMl = 0,
  int mealSlots = 0,
  double? bodyMass = 80,
}) {
  final totals = _day(panel, grams: grams);
  return chargeSigns(
    totals: totals,
    vitality: scoreVitality(totals, bodyMassKg: bodyMass),
    steps: steps,
    distanceM: distanceM,
    stepGoal: 10000,
    loggedDaysInWeek: loggedDays,
    waterMl: waterMl,
    mealSlotsUsed: mealSlots,
  );
}

void main() {
  group('every charge stays in range', () {
    test('for a good day and a bad one', () {
      for (final charges in [
        _charge(_lentils, grams: 300, steps: 14000, loggedDays: 7,
            waterMl: 3000, mealSlots: 4),
        _charge(_candy, grams: 500),
        SignCharges.empty,
      ]) {
        for (final (sign, value) in charges.all) {
          expect(value, inInclusiveRange(0, 1), reason: sign.name);
        }
      }
    });
  });

  group('Igni — protein', () {
    test('agrees with the Vitality component it comes from', () {
      // A day that scores well on protein cannot leave Igni dark. Two rules
      // for the same thing would eventually disagree.
      final totals = _day(_lentils, grams: 300);
      final vitality = scoreVitality(totals, bodyMassKg: 80);

      final charges = chargeSigns(
        totals: totals,
        vitality: vitality,
        steps: 0,
        distanceM: 0,
        stepGoal: 10000,
        loggedDaysInWeek: 0,
      );

      expect(charges[Sign.igni], closeTo(vitality.protein, 0.0001));
    });

    test('is dark on a day with no protein', () {
      expect(_charge(_candy, grams: 400)[Sign.igni], 0);
    });
  });

  group('Quen — fibre and whole food', () {
    test('lights on a whole-food, fibre-rich day', () {
      expect(_charge(_lentils, grams: 300)[Sign.quen], greaterThan(0.8));
    });

    test('stays dark on an ultra-processed day', () {
      expect(_charge(_candy, grams: 400)[Sign.quen], lessThan(0.2));
    });
  });

  group('Aard — movement', () {
    test('rises with steps', () {
      final still = _charge(_lentils)[Sign.aard];
      final walked = _charge(_lentils, steps: 11000, distanceM: 8000)[Sign.aard];

      expect(still, 0);
      expect(walked, greaterThan(0.8));
    });
  });

  group('Axii — consistency and steadiness', () {
    test('is driven mostly by how much of the week was logged', () {
      // Logging is the behaviour the app actually asks for.
      final none = _charge(_lentils, loggedDays: 0)[Sign.axii];
      final every = _charge(_lentils, loggedDays: 7)[Sign.axii];

      expect(every, greaterThan(none));
      expect(every - none, greaterThan(0.5));
    });

    test('a heavy glycemic load dims it', () {
      final steady = _charge(_lentils, grams: 200, loggedDays: 7)[Sign.axii];
      final spiky = _charge(_candy, grams: 400, loggedDays: 7)[Sign.axii];

      expect(spiky, lessThan(steady));
    });

    test('a day with no carbohydrate scores neutral, not perfect', () {
      // An absent glycemic load is not evidence of steadiness.
      const meat = FoodPanel(kcal: 165, proteinG: 31, fatG: 4, novaGroup: 1);

      final charges = _charge(meat, grams: 200, loggedDays: 0);
      // Consistency is zero here, so anything above zero is the neutral
      // steadiness term showing through.
      expect(charges[Sign.axii], greaterThan(0));
      expect(charges[Sign.axii], lessThan(0.2));
    });
  });

  group('Yrden — water and spread', () {
    test('lights with hydration and meals across the day', () {
      final charged =
          _charge(_lentils, waterMl: waterTargetMl, mealSlots: 3)[Sign.yrden];

      expect(charged, closeTo(1.0, 0.0001));
    });

    test('water alone does not fill it', () {
      final waterOnly =
          _charge(_lentils, waterMl: waterTargetMl, mealSlots: 0)[Sign.yrden];

      expect(waterOnly, closeTo(0.6, 0.0001));
    });

    test('it does not matter which source the water came from', () {
      // Yrden is charged from a single total, so tapping the waterskin and
      // logging a drink as food cannot both be counted for the same glass.
      // Hydration is where the two are added; this is the claim that adding
      // them is all that happens.
      const tapped = Hydration(loggedMl: waterTargetMl, fromDrinksMl: 0);
      const drunk = Hydration(loggedMl: 0, fromDrinksMl: waterTargetMl);
      const split = Hydration(
        loggedMl: waterTargetMl ~/ 2,
        fromDrinksMl: waterTargetMl ~/ 2,
      );

      final a = _charge(_lentils, waterMl: tapped.totalMl, mealSlots: 3);
      final b = _charge(_lentils, waterMl: drunk.totalMl, mealSlots: 3);
      final c = _charge(_lentils, waterMl: split.totalMl, mealSlots: 3);

      expect(b[Sign.yrden], a[Sign.yrden]);
      expect(c[Sign.yrden], a[Sign.yrden]);
    });

    test('a fourth meal slot adds nothing', () {
      final three = _charge(_lentils, mealSlots: 3)[Sign.yrden];
      final four = _charge(_lentils, mealSlots: 4)[Sign.yrden];

      // The app does not police when someone eats; spreading across the day is
      // the only claim being made.
      expect(four, three);
    });
  });

  group('SignCharges', () {
    test('lists every sign in order', () {
      final charges = _charge(_lentils, grams: 300);

      expect(charges.all.map((e) => e.$1), Sign.values);
    });

    test('reports which signs are actually doing something', () {
      final charges = _charge(
        _lentils,
        grams: 300,
        steps: 12000,
        distanceM: 9000,
        loggedDays: 7,
        waterMl: 2500,
        mealSlots: 3,
      );

      expect(charges.lit(), contains(Sign.aard));
      expect(charges.lit(), contains(Sign.yrden));
    });

    test('an empty day charges nothing', () {
      expect(SignCharges.empty[Sign.igni], 0);
      expect(SignCharges.empty.lit(), isEmpty);
    });

    test('a day with nothing at all returns the empty charges', () {
      final charges = chargeSigns(
        totals: NutrientTotals.empty,
        vitality: Vitality.empty,
        steps: 0,
        distanceM: 0,
        stepGoal: 10000,
        loggedDaysInWeek: 0,
      );

      expect(charges.all.every((e) => e.$2 == 0), isTrue);
    });
  });

  group('the blackout', () {
    test('no sign reads energy balance', () {
      // The whole row is on the always-visible side of CLAUDE.md §1, which is
      // only safe because every input is the day against itself, against body
      // mass, or against a step goal the user chose.
      final small = _charge(_lentils, grams: 200, loggedDays: 7);
      final large = _charge(_lentils, grams: 600, loggedDays: 7);

      // Three times the food is not a different quality of diet, so the
      // composition-driven signs do not move.
      expect(large[Sign.quen], closeTo(small[Sign.quen], 0.001));
    });
  });
}
