import 'package:cal_tracker/domain/nutrition.dart';
import 'package:flutter_test/flutter_test.dart';

/// Per-100g panels with deliberately round numbers, so every expectation below
/// can be checked by hand rather than by running the code that produced it.
const _oats = FoodPanel(
  kcal: 380,
  proteinG: 13,
  carbsG: 68,
  sugarG: 1,
  fatG: 7,
  satFatG: 1,
  fibreG: 10,
  sodiumMg: 2,
  glycemicIndex: 55,
  novaGroup: 1,
);

const _chicken = FoodPanel(
  kcal: 165,
  proteinG: 31,
  carbsG: 0,
  fatG: 4,
  satFatG: 1,
  sodiumMg: 74,
  novaGroup: 1,
);

const _energyDrink = FoodPanel(
  kcal: 45,
  carbsG: 11,
  sugarG: 11,
  addedSugarG: 11,
  sodiumMg: 100,
  novaGroup: 4,
  additiveCount: 6,
);

void main() {
  group('Serving', () {
    test('scales the panel by the grams eaten', () {
      const serving = Serving(food: _oats, grams: 50);

      expect(serving.portions, 0.5);
      expect(serving.kcal, 190);
      expect(serving.proteinG, 6.5);
      expect(serving.carbsG, 34);
    });

    test('glycemic load is the index weighted by carbohydrate eaten', () {
      const serving = Serving(food: _oats, grams: 100);

      // 55 * 68 / 100.
      expect(serving.glycemicLoad, closeTo(37.4, 0.001));
    });

    test('a food with no index has no load rather than a load of zero', () {
      const serving = Serving(food: _chicken, grams: 200);

      expect(serving.glycemicLoad, isNull);
    });

    test('an unknown figure stays unknown when scaled', () {
      const serving = Serving(food: _oats, grams: 200);

      expect(serving.addedSugarG, isNull);
      expect(serving.transFatG, isNull);
    });
  });

  group('NutrientTotals', () {
    test('an empty day totals zero and knows it is empty', () {
      final totals = NutrientTotals.of(const []);

      expect(totals.isEmpty, isTrue);
      expect(totals.kcal, 0);
      expect(NutrientTotals.empty.isEmpty, isTrue);
    });

    test('sums scaled figures across servings', () {
      final totals = NutrientTotals.of(const [
        Serving(food: _oats, grams: 100),
        Serving(food: _chicken, grams: 200),
      ]);

      expect(totals.kcal, closeTo(380 + 330, 0.001));
      expect(totals.proteinG, closeTo(13 + 62, 0.001));
      expect(totals.fibreG, closeTo(10, 0.001));
      expect(totals.itemCount, 2);
    });

    test('macro energy uses the Atwater factors', () {
      // 25 g protein, 50 g carbs, 10 g fat.
      const panel = FoodPanel(kcal: 999, proteinG: 25, carbsG: 50, fatG: 10);
      final totals = NutrientTotals.of(
        const [Serving(food: panel, grams: 100)],
      );

      expect(totals.proteinKcal, 100);
      expect(totals.carbKcal, 200);
      expect(totals.fatKcal, 90);
      // Not the label's 999: shares must be taken against the same
      // denominator their numerators came from, or they will not sum to 100.
      expect(totals.macroKcal, 390);
    });

    group('average glycemic index', () {
      test('is null when nothing eaten carried an index', () {
        final totals = NutrientTotals.of(
          const [Serving(food: _chicken, grams: 200)],
        );

        expect(totals.averageGlycemicIndex, isNull);
      });

      test('weights by the carbohydrate of foods that had one', () {
        const high = FoodPanel(kcal: 200, carbsG: 50, glycemicIndex: 100);
        const low = FoodPanel(kcal: 200, carbsG: 50, glycemicIndex: 50);

        final totals = NutrientTotals.of(const [
          Serving(food: high, grams: 100),
          Serving(food: low, grams: 100),
        ]);

        // Equal carbohydrate from each, so the mean of 100 and 50.
        expect(totals.averageGlycemicIndex, closeTo(75, 0.001));
      });

      test('a food with no index does not drag the mean towards zero', () {
        const rice = FoodPanel(kcal: 130, carbsG: 28, glycemicIndex: 73);

        final withChicken = NutrientTotals.of(const [
          Serving(food: rice, grams: 100),
          Serving(food: _chicken, grams: 200),
        ]);
        final alone = NutrientTotals.of(
          const [Serving(food: rice, grams: 100)],
        );

        // Chicken has no index, so it is not evidence of a low-GI meal.
        expect(
          withChicken.averageGlycemicIndex,
          closeTo(alone.averageGlycemicIndex!, 0.001),
        );
      });
    });

    group('processing shares', () {
      test('splits energy between whole and ultra-processed food', () {
        final totals = NutrientTotals.of(const [
          // 380 kcal whole.
          Serving(food: _oats, grams: 100),
          // 45 kcal ultra-processed.
          Serving(food: _energyDrink, grams: 100),
        ]);

        expect(totals.wholeFoodKcal, closeTo(380, 0.001));
        expect(totals.ultraProcessedKcal, closeTo(45, 0.001));
        expect(totals.wholeFoodShare, closeTo(380 / 425, 0.001));
        expect(totals.ultraProcessedShare, closeTo(45 / 425, 0.001));
      });

      test('an unknown NOVA group counts as neither', () {
        const unknown = FoodPanel(kcal: 100);
        final totals = NutrientTotals.of(
          const [Serving(food: unknown, grams: 100)],
        );

        // Unknown must not be flattered into "whole", nor condemned as
        // ultra-processed — a hand-typed food is simply unclassified.
        expect(totals.wholeFoodShare, 0);
        expect(totals.ultraProcessedShare, 0);
      });
    });

    test('fibre is reported as density, not quantity', () {
      final small = NutrientTotals.of(
        const [Serving(food: _oats, grams: 100)],
      );
      final large = NutrientTotals.of(
        const [Serving(food: _oats, grams: 200)],
      );

      // Twice the food is twice the fibre but the same quality of diet, which
      // is exactly what a flat gram target would get wrong.
      expect(large.fibreG, closeTo(small.fibreG * 2, 0.001));
      expect(
        large.fibrePer1000Kcal,
        closeTo(small.fibrePer1000Kcal, 0.001),
      );
    });

    test('counts additives across the day', () {
      final totals = NutrientTotals.of(const [
        Serving(food: _energyDrink, grams: 100),
        Serving(food: _energyDrink, grams: 100),
      ]);

      expect(totals.additiveCount, 12);
    });
  });

  group('macroShares', () {
    test('an empty day has no composition at all', () {
      // Not three empty-but-in-range vials: a composition of nothing is not a
      // balanced diet, and showing it as one would reward not logging.
      expect(macroShares(NutrientTotals.empty), isEmpty);
    });

    test('shares are fractions of the day own macro energy', () {
      const panel = FoodPanel(kcal: 390, proteinG: 25, carbsG: 50, fatG: 10);
      final shares = macroShares(
        NutrientTotals.of(const [Serving(food: panel, grams: 100)]),
      );

      expect(shares.map((s) => s.label), ['Protein', 'Carbs', 'Fat']);
      expect(shares[0].share, closeTo(100 / 390, 0.001));
      expect(shares[1].share, closeTo(200 / 390, 0.001));
      expect(shares[2].share, closeTo(90 / 390, 0.001));

      // And they account for the whole day.
      final sum = shares.fold<double>(0, (a, s) => a + s.share);
      expect(sum, closeTo(1.0, 0.001));
    });

    test('reports where a share sits against the usual range', () {
      // 90% of energy from fat.
      const fatty = FoodPanel(kcal: 900, proteinG: 0, carbsG: 0, fatG: 100);
      final shares = macroShares(
        NutrientTotals.of(const [Serving(food: fatty, grams: 100)]),
      );

      final fat = shares.firstWhere((s) => s.label == 'Fat');
      final carbs = shares.firstWhere((s) => s.label == 'Carbs');

      expect(fat.isAboveRange, isTrue);
      expect(carbs.isBelowRange, isTrue);
      expect(fat.isInRange, isFalse);
    });

    test('an over-range macro visibly overfills its vial', () {
      const fatty = FoodPanel(kcal: 900, fatG: 100);
      final shares = macroShares(
        NutrientTotals.of(const [Serving(food: fatty, grams: 100)]),
      );
      final fat = shares.firstWhere((s) => s.label == 'Fat');

      expect(fat.fillFraction, greaterThan(1.0));
      // But not unboundedly — the vial has to stay on screen.
      expect(fat.fillFraction, lessThanOrEqualTo(1.25));
    });

    test('the ranges are the published AMDR figures', () {
      // Pinned because they are public guidance, not a target this app chose.
      // A change here is a change of claim and should be argued about.
      expect(Amdr.carbs, (low: 0.45, high: 0.65));
      expect(Amdr.fat, (low: 0.20, high: 0.35));
      expect(Amdr.protein, (low: 0.10, high: 0.35));
    });
  });

  group('proteinPerKg', () {
    test('divides protein by body mass', () {
      final totals = NutrientTotals.of(
        const [Serving(food: _chicken, grams: 400)],
      );

      // 124 g of protein at 80 kg.
      expect(proteinPerKg(totals, 80), closeTo(1.55, 0.001));
    });

    test('is null without a weigh-in to work from', () {
      final totals = NutrientTotals.of(
        const [Serving(food: _chicken, grams: 200)],
      );

      expect(proteinPerKg(totals, null), isNull);
      expect(proteinPerKg(totals, 0), isNull);
    });
  });

  group('the blackout', () {
    test('nothing in the rollup compares intake to expenditure', () {
      // The engine is given no way to know what the user was meant to eat, so
      // no arrangement of its output can be solved back into a deficit.
      // If a future change adds a TDEE, goal or remainder to these types, this
      // is where it should be argued about. See CLAUDE.md §1.
      final totals = NutrientTotals.of(
        const [Serving(food: _oats, grams: 100)],
      );

      final surface = [
        totals.toString(),
        NutrientTotals.empty.toString(),
        macroShares(totals).map((s) => s.label).join(' '),
      ].join(' ').toLowerCase();

      for (final banned in const [
        'tdee',
        'deficit',
        'surplus',
        'remaining',
        'maintenance',
        'target',
        'goal',
      ]) {
        expect(surface, isNot(contains(banned)), reason: 'leaked "$banned"');
      }
    });
  });
}
