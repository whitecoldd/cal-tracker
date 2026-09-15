import 'package:cal_tracker/domain/bestiary.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/harm.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/rarity.dart';
import 'package:flutter_test/flutter_test.dart';

const _lentils = FoodPanel(
  kcal: 352,
  proteinG: 25,
  carbsG: 60,
  fibreG: 11,
  novaGroup: 1,
);

const _drink = FoodPanel(
  kcal: 45,
  carbsG: 11,
  sugarG: 11,
  addedSugarG: 11,
  sodiumMg: 100,
  novaGroup: 4,
  additiveCount: 6,
);

const _chicken = FoodPanel(
  kcal: 165,
  proteinG: 31,
  fatG: 4,
  novaGroup: 1,
);

Creature _creature(
  int id,
  String name,
  FoodPanel panel, {
  int timesEaten = 1,
  Day? firstSeen,
  String? brand,
}) =>
    Creature.of(
      id: id,
      name: name,
      panel: panel,
      brand: brand,
      timesEaten: timesEaten,
      firstSeen: firstSeen,
    );

void main() {
  group('a creature entry', () {
    test('takes its rarity and weaknesses from the scoring engine', () {
      // The same two calls the food picker makes. A food must not read Epic in
      // the picker and Rare in the collection.
      final lentils = _creature(1, 'Red lentils', _lentils);

      expect(lentils.rarity, rankFood(_lentils));
      expect(lentils.toxicity, closeTo(readFoodToxins(_lentils).load, 0.0001));
    });

    test('an ultra-processed food carries visible weaknesses', () {
      final drink = _creature(2, 'Energy drink', _drink);

      expect(drink.rarity, FoodRarity.common);
      expect(drink.weaknesses, isNotEmpty);
      expect(
        drink.weaknesses.map((w) => w.kind),
        contains(HarmKind.ultraProcessed),
      );
    });

    test('a clean whole food has few', () {
      expect(_creature(3, 'Chicken', _chicken).weaknesses.length, lessThan(3));
    });

    test('knows whether it has actually been eaten', () {
      // The library holds the whole seed table from first launch, so "known"
      // and "caught" are different — a Bestiary claiming 132 creatures on day
      // one would mean nothing.
      expect(_creature(1, 'A', _lentils, timesEaten: 0).isCaught, isFalse);
      expect(_creature(1, 'A', _lentils, timesEaten: 1).isCaught, isTrue);
    });
  });

  group('arranging the collection', () {
    final creatures = [
      _creature(1, 'Bread', _drink,
          timesEaten: 9, firstSeen: const Day(20260901)),
      _creature(2, 'Almonds', _lentils,
          timesEaten: 2, firstSeen: const Day(20260910)),
      _creature(3, 'Chicken', _chicken,
          timesEaten: 5, firstSeen: const Day(20260905)),
      _creature(4, 'Never eaten', _lentils, timesEaten: 0),
    ];

    test('shows only what has been caught by default', () {
      final shown = arrange(creatures);

      expect(shown.map((c) => c.name), isNot(contains('Never eaten')));
      expect(shown, hasLength(3));
    });

    test('can show the whole library', () {
      expect(arrange(creatures, filter: BestiaryFilter.all), hasLength(4));
    });

    test('orders by most eaten', () {
      final shown = arrange(creatures, order: BestiaryOrder.mostEaten);

      expect(shown.map((c) => c.name), ['Bread', 'Chicken', 'Almonds']);
    });

    test('orders by rarity, best first', () {
      final shown = arrange(creatures, order: BestiaryOrder.rarity);

      expect(shown.first.rarity.index, greaterThanOrEqualTo(shown.last.rarity.index));
    });

    test('orders by name', () {
      final shown = arrange(creatures, order: BestiaryOrder.name);

      expect(shown.map((c) => c.name), ['Almonds', 'Bread', 'Chicken']);
    });

    test('orders by most toxic', () {
      final shown = arrange(creatures, order: BestiaryOrder.toxicity);

      expect(shown.first.name, 'Bread');
    });

    test('orders by newest found', () {
      final shown = arrange(creatures, order: BestiaryOrder.recent);

      expect(shown.map((c) => c.name), ['Almonds', 'Chicken', 'Bread']);
    });

    test('a never-eaten food sorts last when the whole library is shown', () {
      final shown = arrange(
        creatures,
        order: BestiaryOrder.recent,
        filter: BestiaryFilter.all,
      );

      // The collection is about what was found.
      expect(shown.last.name, 'Never eaten');
    });

    test('ties break by name, so a redraw does not shuffle the page', () {
      final tied = [
        _creature(1, 'Zebra', _chicken, timesEaten: 3),
        _creature(2, 'Aurochs', _chicken, timesEaten: 3),
      ];

      expect(
        arrange(tied, order: BestiaryOrder.mostEaten).map((c) => c.name),
        ['Aurochs', 'Zebra'],
      );
    });

    group('searching', () {
      test('matches a name', () {
        expect(arrange(creatures, query: 'chick').single.name, 'Chicken');
      });

      test('matches a brand', () {
        final branded = [
          _creature(1, 'Chocolate', _drink, brand: 'Milka'),
        ];

        expect(arrange(branded, query: 'milka'), hasLength(1));
      });

      test('ignores case and surrounding space', () {
        expect(arrange(creatures, query: '  BREAD '), hasLength(1));
      });

      test('an empty query filters nothing', () {
        expect(arrange(creatures, query: '   '), hasLength(3));
      });
    });
  });

  group('progress', () {
    test('counts caught against known', () {
      final progress = progressOf([
        _creature(1, 'A', _lentils, timesEaten: 3),
        _creature(2, 'B', _lentils, timesEaten: 0),
        _creature(3, 'C', _lentils, timesEaten: 1),
      ]);

      expect(progress.caught, 2);
      expect(progress.known, 3);
      expect(progress.fraction, closeTo(2 / 3, 0.001));
    });

    test('an empty library does not divide by zero', () {
      expect(progressOf(const []).fraction, 0);
    });

    test('counts caught creatures by tier', () {
      final counts = BestiaryProgress.byRarity([
        _creature(1, 'Lentils', _lentils),
        _creature(2, 'Drink', _drink),
        // Never eaten, so it is not in the collection.
        _creature(3, 'Unseen', _lentils, timesEaten: 0),
      ]);

      expect(counts[rankFood(_lentils)], 1);
      expect(counts[FoodRarity.common], 1);
      // Every tier is present as a key, even at zero, so the UI can show the
      // gaps rather than hiding them.
      expect(counts.keys, containsAll(FoodRarity.values));
    });
  });

  group('order and filter labels', () {
    test('every option has one', () {
      for (final order in BestiaryOrder.values) {
        expect(order.label, isNotEmpty);
      }
      for (final filter in BestiaryFilter.values) {
        expect(filter.label, isNotEmpty);
      }
    });
  });
}
