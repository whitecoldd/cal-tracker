import 'package:cal_tracker/domain/portion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePortion', () {
    test('exact units convert one for one and are fully trusted', () {
      final grams = resolvePortion(quantity: 80, unit: PortionUnit.grams);
      expect(grams.grams, 80);
      expect(grams.confidence, 1);
      expect(grams.worthRefining, isFalse);

      final ml = resolvePortion(quantity: 250, unit: PortionUnit.millilitres);
      expect(ml.grams, 250);
    });

    test('a food that knows its own piece weight beats the generic default',
        () {
      final egg = resolvePortion(
        quantity: 2,
        unit: PortionUnit.piece,
        gramsPerPiece: 50,
      );
      expect(egg.grams, 100);
      expect(egg.usedPieceWeight, isTrue);
      expect(egg.confidence, 0.95);
      expect(egg.worthRefining, isFalse);

      final unknown = resolvePortion(quantity: 2, unit: PortionUnit.piece);
      expect(unknown.grams, 200, reason: 'falls back to 100g per piece');
      expect(unknown.usedPieceWeight, isFalse);
      expect(unknown.worthRefining, isTrue);
    });

    test('vague units resolve to something, and admit they are vague', () {
      for (final unit in [
        PortionUnit.handful,
        PortionUnit.bowl,
        PortionUnit.plate,
      ]) {
        final portion = resolvePortion(quantity: 1, unit: unit);
        expect(portion.grams, greaterThan(0), reason: unit.name);
        expect(portion.worthRefining, isTrue, reason: unit.name);
      }
    });

    test('kitchen measures are trusted more than hands and plates', () {
      final spoon = resolvePortion(quantity: 1, unit: PortionUnit.tablespoon);
      final hand = resolvePortion(quantity: 1, unit: PortionUnit.handful);

      expect(spoon.confidence, greaterThan(hand.confidence));
      expect(spoon.worthRefining, isFalse);
      expect(hand.worthRefining, isTrue);
    });

    test('a piece weight is ignored by units that are not pieces', () {
      // 100g of egg is 100g, whatever one egg happens to weigh.
      final portion = resolvePortion(
        quantity: 100,
        unit: PortionUnit.grams,
        gramsPerPiece: 50,
      );
      expect(portion.grams, 100);
      expect(portion.usedPieceWeight, isFalse);
    });

    test('a zero, negative or non-finite quantity resolves to zero grams', () {
      for (final quantity in [0.0, -5.0, double.nan, double.infinity]) {
        expect(
          resolvePortion(quantity: quantity, unit: PortionUnit.grams).grams,
          0,
          reason: '$quantity',
        );
      }
    });

    test('a zero piece weight falls back rather than resolving to nothing', () {
      // A food row with gramsPerPiece of 0 is bad data, not a zero-gram food.
      final portion = resolvePortion(
        quantity: 2,
        unit: PortionUnit.piece,
        gramsPerPiece: 0,
      );
      expect(portion.grams, 200);
      expect(portion.usedPieceWeight, isFalse);
    });

    test('quantity scales the result linearly', () {
      final one = resolvePortion(quantity: 1, unit: PortionUnit.handful).grams;
      final three =
          resolvePortion(quantity: 3, unit: PortionUnit.handful).grams;
      expect(three, closeTo(one * 3, 1e-9));
    });
  });

  group('describePortion', () {
    test('exact units read as a measurement', () {
      expect(
        describePortion(quantity: 80, unit: PortionUnit.grams),
        '80g',
      );
      expect(
        describePortion(quantity: 250, unit: PortionUnit.millilitres),
        '250ml',
      );
    });

    test('pieces borrow the food’s own noun', () {
      // "2 eggs" rather than "2 pieces" — the Journal is meant to read like a
      // journal, and your own words make a wrong entry obvious.
      expect(
        describePortion(
          quantity: 2,
          unit: PortionUnit.piece,
          pieceName: 'egg',
        ),
        '2 eggs',
      );
      expect(
        describePortion(
          quantity: 1,
          unit: PortionUnit.piece,
          pieceName: 'egg',
        ),
        '1 egg',
      );
    });

    test('falls back to the unit name when the food has no noun', () {
      expect(describePortion(quantity: 2, unit: PortionUnit.piece), '2 pieces');
      expect(describePortion(quantity: 1, unit: PortionUnit.slice), '1 slice');
    });

    test('vague units read the way people speak', () {
      expect(
        describePortion(quantity: 1, unit: PortionUnit.handful),
        '1 handful',
      );
      expect(
        describePortion(quantity: 2, unit: PortionUnit.handful),
        '2 handfuls',
      );
      expect(describePortion(quantity: 1, unit: PortionUnit.plate), '1 plate');
    });

    test('pluralises a noun already ending in s without doubling it', () {
      expect(
        describePortion(
          quantity: 2,
          unit: PortionUnit.piece,
          pieceName: 'glass',
        ),
        '2 glasses',
      );
    });

    test('halves and fractions survive the round trip', () {
      expect(
        describePortion(quantity: 0.5, unit: PortionUnit.plate),
        '0.5 plates',
      );
      expect(describePortion(quantity: 1.5, unit: PortionUnit.grams), '1.5g');
    });
  });

  group('unit metadata', () {
    test('only grams and millilitres claim to be exact', () {
      final exact = PortionUnit.values.where((u) => u.isExact).toSet();
      expect(exact, {PortionUnit.grams, PortionUnit.millilitres});
    });

    test('only pieces and slices consult a food’s piece weight', () {
      final piecey = PortionUnit.values.where((u) => u.usesPieceWeight).toSet();
      expect(piecey, {PortionUnit.piece, PortionUnit.slice});
    });

    test('every unit has a plausible default weight and a label', () {
      for (final unit in PortionUnit.values) {
        expect(unit.defaultGrams, greaterThan(0), reason: unit.name);
        expect(unit.baseConfidence, inInclusiveRange(0, 1), reason: unit.name);
        expect(unit.short.trim(), isNotEmpty, reason: unit.name);
        expect(unit.label.trim(), isNotEmpty, reason: unit.name);
      }
    });
  });
}
