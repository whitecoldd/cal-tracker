import 'package:cal_tracker/domain/harm.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a day from a single 100 g panel, so each guideline can be pushed on
/// in isolation.
Toxins _day(FoodPanel panel, {double grams = 100}) =>
    readToxins(NutrientTotals.of([Serving(food: panel, grams: grams)]));

void main() {
  group('sodium', () {
    test('reads full severity at the WHO guideline', () {
      final toxins = _day(const FoodPanel(kcal: 100, sodiumMg: 2000));

      expect(toxins[HarmKind.sodium]!.severity, closeTo(1.0, 0.001));
      expect(toxins[HarmKind.sodium]!.detail, contains('2000 mg'));
    });

    test('keeps rising past the guideline', () {
      final at = _day(const FoodPanel(kcal: 100, sodiumMg: 2000));
      final triple = _day(const FoodPanel(kcal: 100, sodiumMg: 6000));

      // Three times the guideline must not record as the same as reaching it.
      expect(
        triple[HarmKind.sodium]!.severity,
        greaterThan(at[HarmKind.sodium]!.severity),
      );
    });
  });

  group('free sugars', () {
    test('are measured against 10% of the day energy', () {
      // 390 kcal of macros, 10% of which is 39 kcal — 9.75 g of sugar.
      const panel = FoodPanel(
        kcal: 390,
        proteinG: 25,
        carbsG: 50,
        fatG: 10,
        addedSugarG: 9.75,
      );

      expect(_day(panel)[HarmKind.addedSugar]!.severity, closeTo(1.0, 0.01));
    });

    test('an unknown figure is not counted as zero sugar', () {
      // Nothing is claimed either way, so the flag reads nothing — but the
      // food is not exonerated by silence either. See the addedSugarG doc.
      const unknown = FoodPanel(kcal: 400, carbsG: 100);

      expect(_day(unknown)[HarmKind.addedSugar]!.severity, 0);
    });
  });

  group('trans fat', () {
    test('any recorded amount registers, because the advice is elimination',
        () {
      const panel = FoodPanel(kcal: 900, fatG: 100, transFatG: 2);

      final flag = _day(panel)[HarmKind.transFat]!;
      expect(flag.severity, greaterThan(0));
      expect(flag.detail, contains('2.0 g'));
    });

    test('says so plainly when there is none', () {
      const clean = FoodPanel(kcal: 165, proteinG: 31, transFatG: 0);

      expect(_day(clean)[HarmKind.transFat]!.detail, 'None recorded');
    });
  });

  group('alcohol', () {
    test('is reported in units of 8 g of ethanol', () {
      const beer = FoodPanel(kcal: 43, alcoholG: 16);

      final flag = _day(beer)[HarmKind.alcohol]!;
      expect(flag.detail, contains('2.0 units'));
      expect(flag.severity, closeTo(1.0, 0.001));
    });
  });

  group('processing', () {
    test('ultra-processed share drives the refined-matter flag', () {
      const junk = FoodPanel(kcal: 500, carbsG: 60, fatG: 25, novaGroup: 4);

      final flag = _day(junk)[HarmKind.ultraProcessed]!;
      // All of the day energy, against a 50% reference.
      expect(flag.severity, closeTo(2.0, 0.001));
      expect(flag.detail, contains('100%'));
    });

    test('additives are counted, and the count is worded for one', () {
      const one = FoodPanel(kcal: 100, novaGroup: 4, additiveCount: 1);
      const many = FoodPanel(kcal: 100, novaGroup: 4, additiveCount: 5);

      expect(_day(one)[HarmKind.additives]!.detail, '1 additive listed');
      expect(_day(many)[HarmKind.additives]!.detail, '5 additives listed');
    });
  });

  group('the day load', () {
    test('an empty day carries no harm', () {
      expect(readToxins(NutrientTotals.empty).load, 0);
      expect(readToxins(NutrientTotals.empty).flags, isEmpty);
    });

    test('a clean whole-food day scores near nothing', () {
      const oats = FoodPanel(
        kcal: 380,
        proteinG: 13,
        carbsG: 68,
        fatG: 7,
        satFatG: 1,
        fibreG: 10,
        sodiumMg: 2,
        novaGroup: 1,
      );

      expect(_day(oats).load, lessThan(10));
    });

    test('a bad day scores high', () {
      const bad = FoodPanel(
        kcal: 600,
        carbsG: 70,
        sugarG: 60,
        addedSugarG: 60,
        fatG: 30,
        satFatG: 20,
        transFatG: 3,
        sodiumMg: 2500,
        alcoholG: 20,
        novaGroup: 4,
        additiveCount: 9,
      );

      expect(_day(bad).load, greaterThan(70));
    });

    test('is bounded, so one catastrophic figure cannot saturate the meter',
        () {
      const absurd = FoodPanel(kcal: 100, sodiumMg: 500000);

      final flag = _day(absurd)[HarmKind.sodium]!;
      // The reading itself is honest about how far past the guideline it is...
      expect(flag.severity, greaterThan(100));
      // ...but it cannot consume the whole meter and hide everything else.
      expect(_day(absurd).load, lessThan(20));
    });

    test('never exceeds 100', () {
      const everything = FoodPanel(
        kcal: 1000,
        carbsG: 200,
        addedSugarG: 200,
        fatG: 100,
        satFatG: 90,
        transFatG: 50,
        sodiumMg: 20000,
        alcoholG: 200,
        novaGroup: 4,
        additiveCount: 40,
      );

      expect(_day(everything).load, lessThanOrEqualTo(100));
    });
  });

  group('presentation', () {
    test('orders the readings worst first', () {
      const panel = FoodPanel(
        kcal: 400,
        carbsG: 50,
        sodiumMg: 4000,
        novaGroup: 1,
      );

      final flags = _day(panel).flags;
      for (var i = 1; i < flags.length; i++) {
        expect(
          flags[i - 1].severity,
          greaterThanOrEqualTo(flags[i].severity),
        );
      }
      // Sodium is the only thing wrong with this day, so it leads.
      expect(flags.first.kind, HarmKind.sodium);
    });

    test('notable drops the readings that measured nothing', () {
      const clean = FoodPanel(kcal: 165, proteinG: 31, novaGroup: 1);

      final toxins = _day(clean);
      expect(toxins.flags, isNotEmpty);
      expect(toxins.notable.every((f) => f.severity > 0), isTrue);
    });

    test('every kind states what it is measured against', () {
      for (final kind in HarmKind.values) {
        expect(kind.basis, isNotEmpty, reason: '${kind.name} has no basis');
        expect(kind.title, isNotEmpty);
      }
    });

    test('the disclaimer names itself as not medical advice', () {
      // Required on every harm surface by CLAUDE.md §7.
      final text = harmDisclaimer.toLowerCase();
      expect(text, contains('not medical advice'));
      expect(text, contains('physician'));
    });

    test('no reading is phrased as a diagnosis', () {
      const bad = FoodPanel(
        kcal: 600,
        addedSugarG: 60,
        satFatG: 20,
        transFatG: 3,
        sodiumMg: 4000,
        alcoholG: 30,
        novaGroup: 4,
        additiveCount: 9,
      );

      final surface = [
        for (final flag in _day(bad).flags)
          '${flag.kind.title} ${flag.kind.basis} ${flag.detail}',
        harmDisclaimer,
      ].join(' ').toLowerCase();

      // Harm is lore drawn from public guidance, never a claim about this
      // person's body. See CLAUDE.md §7.
      for (final banned in const [
        'you will',
        'causes',
        'disease',
        'diabetes',
        'cancer',
        'obese',
        'unhealthy',
        'dangerous',
        'toxic to you',
      ]) {
        expect(surface, isNot(contains(banned)), reason: 'diagnostic: $banned');
      }
    });
  });

  group('readFoodToxins', () {
    test('reads a single food per 100 g, independent of any portion', () {
      const drink = FoodPanel(
        kcal: 45,
        carbsG: 11,
        addedSugarG: 11,
        sodiumMg: 100,
        novaGroup: 4,
        additiveCount: 6,
      );

      final food = readFoodToxins(drink);
      final asDay = _day(drink);

      // A Bestiary entry describes what a thing is, not how much of it was
      // eaten once, so the two must agree.
      expect(food.load, closeTo(asDay.load, 0.001));
      expect(food[HarmKind.ultraProcessed]!.severity, greaterThan(0));
    });
  });
}
