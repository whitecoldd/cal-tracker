import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

NutrientTotals _day(FoodPanel panel, {double grams = 100}) =>
    NutrientTotals.of([Serving(food: panel, grams: grams)]);

/// Lentils: whole, fibre-rich, decent protein. The diet the app approves of.
const _lentils = FoodPanel(
  kcal: 350,
  proteinG: 25,
  carbsG: 60,
  sugarG: 2,
  addedSugarG: 0,
  fatG: 1,
  satFatG: 0,
  fibreG: 30,
  sodiumMg: 6,
  novaGroup: 1,
);

/// A NOVA-4 day: no fibre, all free sugar.
const _candy = FoodPanel(
  kcal: 400,
  proteinG: 0,
  carbsG: 100,
  sugarG: 90,
  addedSugarG: 90,
  fatG: 0,
  fibreG: 0,
  sodiumMg: 50,
  novaGroup: 4,
  additives: ['E100', 'E101', 'E102', 'E104', 'E110'],
);

void main() {
  group('Vitality', () {
    test('an unlogged day scores nothing, not full marks', () {
      // The trap the whole function is arranged around: an empty day has no
      // sugar, no sodium and no ultra-processed food, so every restraint
      // component would read perfect. That would make not logging the
      // highest-scoring strategy in the app.
      expect(scoreVitality(NutrientTotals.empty).score, 0);
      expect(scoreVitality(NutrientTotals.empty, bodyMassKg: 80).score, 0);
    });

    test('a whole-food day scores well', () {
      final score = scoreVitality(_day(_lentils), bodyMassKg: 80).score;

      expect(score, greaterThan(70));
    });

    test('an ultra-processed sugar day scores badly', () {
      final score = scoreVitality(_day(_candy), bodyMassKg: 80).score;

      expect(score, lessThan(20));
    });

    test('is bounded to 0..100', () {
      const extreme = FoodPanel(
        kcal: 100,
        proteinG: 90,
        fibreG: 90,
        novaGroup: 1,
      );

      final score = scoreVitality(_day(extreme), bodyMassKg: 40).score;
      expect(score, lessThanOrEqualTo(100));
      expect(score, greaterThanOrEqualTo(0));
    });

    group('components', () {
      test('fibre is scored as density, so eating more does not help', () {
        final small = scoreVitality(_day(_lentils), bodyMassKg: 80);
        final large =
            scoreVitality(_day(_lentils, grams: 300), bodyMassKg: 80);

        expect(large.fibre, closeTo(small.fibre, 0.001));
      });

      test('whole food follows the share of energy from NOVA 1-2', () {
        expect(scoreVitality(_day(_lentils)).wholeFood, 1.0);
        expect(scoreVitality(_day(_candy)).wholeFood, 0.0);
      });

      test('sugar restraint falls as free sugars approach the guideline', () {
        expect(scoreVitality(_day(_lentils)).sugarRestraint, 1.0);
        expect(scoreVitality(_day(_candy)).sugarRestraint, 0.0);
      });

      test('protein is measured per kilogram when a weigh-in exists', () {
        // 25 g of protein at 40 kg is 0.625 g/kg, against a 1.6 target.
        final light = scoreVitality(_day(_lentils), bodyMassKg: 40);
        final heavy = scoreVitality(_day(_lentils), bodyMassKg: 100);

        expect(light.protein, greaterThan(heavy.protein));
        expect(light.protein, closeTo(0.625 / 1.6, 0.001));
      });

      test('falls back to a share reading with no weigh-in', () {
        final scored = scoreVitality(_day(_lentils));

        // Still scores something rather than zeroing the component, but from
        // composition rather than a guess about body mass.
        expect(scored.protein, greaterThan(0));
      });
    });

    test('reads nothing about energy balance', () {
      // Vitality is listed as always-visible in CLAUDE.md §1, which is only
      // safe because every input is the day against itself or against body
      // mass. Weight is logged and shown daily; only its interpretation is
      // sealed. Nothing here is given a TDEE to compare against.
      final a = scoreVitality(_day(_lentils), bodyMassKg: 80);
      final b = scoreVitality(_day(_lentils, grams: 1000), bodyMassKg: 80);

      // Ten times the food is not a different quality of diet, except through
      // protein adequacy — so the composition components are unmoved.
      expect(b.wholeFood, closeTo(a.wholeFood, 0.001));
      expect(b.fibre, closeTo(a.fibre, 0.001));
      expect(b.sugarRestraint, closeTo(a.sugarRestraint, 0.001));
    });
  });

  group('Toxicity', () {
    test('a clean run stays at zero', () {
      expect(Toxicity.across(const [0, 0, 0, 0, 0, 0, 0]), 0);
    });

    test('one bad day still colours the next', () {
      final after = Toxicity.next(40, 0);

      expect(after, closeTo(40 * Toxicity.dailyRetention, 0.001));
      expect(after, greaterThan(0));
    });

    test('a bad Friday is faint by Monday', () {
      // Friday load of 60, then three clean days.
      final monday = Toxicity.across(const [60, 0, 0, 0]);

      expect(monday, lessThan(15));
      expect(monday, greaterThan(0));
    });

    test('accumulates across consecutive bad days', () {
      final one = Toxicity.across(const [50]);
      final three = Toxicity.across(const [50, 50, 50]);

      expect(three, greaterThan(one));
    });

    test('is bounded at 100 however bad the run', () {
      expect(
        Toxicity.across(const [100, 100, 100, 100, 100, 100, 100]),
        lessThanOrEqualTo(100),
      );
    });

    test('never goes negative', () {
      expect(Toxicity.next(0, 0), 0);
      expect(Toxicity.across(const [0]), greaterThanOrEqualTo(0));
    });

    test('the window is long enough that what falls off does not matter', () {
      // Anything older than the window contributes less than a percent of a
      // full day, which is below what the meter can show.
      expect(Toxicity.residueAfter(Toxicity.window), lessThan(0.02));
    });

    test('a purge perk makes a bad day fade faster', () {
      // White Honey is 0.15: fifteen percent less of yesterday survives into
      // today. Same load, same days, less left over.
      const loads = [80.0, 0.0, 0.0];
      final purged = Toxicity.retentionWith(0.15);

      expect(purged, lessThan(Toxicity.dailyRetention));
      expect(
        Toxicity.across(loads, retention: purged),
        lessThan(Toxicity.across(loads)),
      );
    });

    test('no purge is exactly the unmodified decay', () {
      // The default has to stay the default: a user with no mutagen must get
      // the same number they got before perks were ever spent.
      expect(Toxicity.retentionWith(0), Toxicity.dailyRetention);
      expect(
        Toxicity.across(const [40.0, 20.0], retention: Toxicity.retentionWith(0)),
        Toxicity.across(const [40.0, 20.0]),
      );
    });

    test("a purge cannot make today's own food weigh less", () {
      // It softens the *carry-over*, not the meal. A single day with nothing
      // before it reads the same however strong the perk is.
      expect(
        Toxicity.across(const [70.0], retention: Toxicity.retentionWith(0.9)),
        Toxicity.across(const [70.0]),
      );
    });

    test('residue decays monotonically', () {
      var previous = 1.0;
      for (var day = 1; day <= Toxicity.window; day++) {
        final residue = Toxicity.residueAfter(day);
        expect(residue, lessThan(previous));
        previous = residue;
      }
    });

    test('folding is the same as stepping day by day', () {
      const loads = [30.0, 0.0, 55.0, 10.0];

      var stepped = 0.0;
      for (final load in loads) {
        stepped = Toxicity.next(stepped, load);
      }

      expect(Toxicity.across(loads), closeTo(stepped, 0.001));
    });
  });
}
