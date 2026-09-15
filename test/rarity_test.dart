import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/rarity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rankFood', () {
    test('lentils outrank an energy drink', () {
      // The sentence the whole ranking exists to make true, from
      // vault/03-Game-Design.
      const lentils = FoodPanel(
        kcal: 350,
        proteinG: 25,
        carbsG: 60,
        fibreG: 30,
        novaGroup: 1,
      );
      const drink = FoodPanel(
        kcal: 45,
        carbsG: 11,
        sugarG: 11,
        novaGroup: 4,
        additiveCount: 6,
      );

      expect(rankFood(lentils).index, greaterThan(rankFood(drink).index));
      expect(rankFood(drink), FoodRarity.common);
    });

    test('processing outranks density', () {
      // An ultra-processed protein bar is dense but still Common: NOVA comes
      // from the ingredient list and is the more reliable signal.
      const bar = FoodPanel(kcal: 400, proteinG: 30, fibreG: 10, novaGroup: 4);
      const plainOats = FoodPanel(kcal: 380, proteinG: 13, novaGroup: 1);

      expect(rankFood(bar), FoodRarity.common);
      expect(rankFood(plainOats), FoodRarity.rare);
    });

    test('an unprocessed food rises with density', () {
      const plain = FoodPanel(kcal: 100, novaGroup: 1);
      const fibrous = FoodPanel(kcal: 100, fibreG: 6, novaGroup: 1);
      const both = FoodPanel(
        kcal: 350,
        proteinG: 25,
        fibreG: 30,
        novaGroup: 1,
      );

      expect(rankFood(plain), FoodRarity.rare);
      expect(rankFood(fibrous), FoodRarity.epic);
      expect(rankFood(both), FoodRarity.relic);
    });

    test('a processed but decent food sits in the middle', () {
      const tinnedBeans = FoodPanel(
        kcal: 90,
        proteinG: 5,
        fibreG: 6,
        novaGroup: 2,
      );
      const oil = FoodPanel(kcal: 900, fatG: 100, novaGroup: 2);

      expect(rankFood(tinnedBeans), FoodRarity.rare);
      expect(rankFood(oil), FoodRarity.common);
    });

    test('an unknown processing group is Common, not flattered upwards', () {
      // Every hand-typed food has no NOVA group. Guessing upwards would make
      // the whole library look excellent and the rarity meaningless.
      const typed = FoodPanel(kcal: 200, proteinG: 40, fibreG: 20);

      expect(rankFood(typed), FoodRarity.common);
    });

    test('every rarity has a name to show', () {
      for (final rarity in FoodRarity.values) {
        expect(rarity.title, isNotEmpty);
      }
    });

    test('the tiers are ordered worst to best', () {
      expect(FoodRarity.values, [
        FoodRarity.common,
        FoodRarity.rare,
        FoodRarity.epic,
        FoodRarity.relic,
      ]);
    });
  });
}
