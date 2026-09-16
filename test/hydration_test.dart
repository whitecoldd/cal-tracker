import 'package:cal_tracker/domain/hydration.dart';
import 'package:cal_tracker/domain/signs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hydrationFactor', () {
    test('water and soft drinks credit their full volume', () {
      expect(hydrationFactor(const Drink(millilitres: 500)), 1);
    });

    test('anything with alcohol in it credits nothing', () {
      // Not a health claim about beer. Alcohol is the only diuretic this app
      // stores a figure for, and crediting zero is the simplification that can
      // never overstate how much someone has drunk.
      expect(
        hydrationFactor(const Drink(millilitres: 330, alcoholG: 12.9)),
        0,
      );
    });

    test('a trace of alcohol is still alcohol', () {
      expect(hydrationFactor(const Drink(millilitres: 100, alcoholG: 0.1)), 0);
    });
  });

  group('hydrationFromDrinks', () {
    test('sums what counts and drops what does not', () {
      final ml = hydrationFromDrinks(const [
        Drink(millilitres: 500),
        Drink(millilitres: 250),
        Drink(millilitres: 330, alcoholG: 12.9),
      ]);

      expect(ml, 750);
    });

    test('nothing drunk is nothing credited', () {
      expect(hydrationFromDrinks(const []), 0);
    });

    test('rounds to whole millilitres', () {
      expect(hydrationFromDrinks(const [Drink(millilitres: 249.6)]), 250);
    });
  });

  group('Hydration', () {
    test('adds the tapped figure to what was drunk as food', () {
      const hydration = Hydration(loggedMl: 1000, fromDrinksMl: 500);
      expect(hydration.totalMl, 1500);
    });

    test('the two sources are disjoint, so nothing is counted twice', () {
      // One is a water_logs row, the other derives from entries. A day of
      // 2,000 reads the same however it was split between them.
      const tapped = Hydration(loggedMl: 2000, fromDrinksMl: 0);
      const drunk = Hydration(loggedMl: 0, fromDrinksMl: 2000);
      const split = Hydration(loggedMl: 1000, fromDrinksMl: 1000);

      expect(tapped.totalMl, drunk.totalMl);
      expect(split.totalMl, tapped.totalMl);
      expect(tapped.fraction, drunk.fraction);
      expect(split.fraction, tapped.fraction);
    });

    test('fraction clamps rather than running past the glyph', () {
      const flood = Hydration(loggedMl: waterTargetMl * 3, fromDrinksMl: 0);
      expect(flood.fraction, 1);
    });

    test('an empty day is empty', () {
      expect(Hydration.empty.totalMl, 0);
      expect(Hydration.empty.fraction, 0);
    });
  });
}
