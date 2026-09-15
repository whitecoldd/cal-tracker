import 'package:cal_tracker/data/ai/meal_resolver.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/nutrition.dart';
import 'package:cal_tracker/domain/parsed_meal.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-09-15T10:00:00.000';

ParsedItem _item({
  String name = 'Egg, whole',
  String? brand,
  double kcal = 150,
  double protein = 12,
  double quantity = 2,
  PortionUnit unit = PortionUnit.piece,
  double? grams,
  double confidence = 0.9,
  int? nova = 1,
}) {
  return ParsedItem(
    food: ParsedFood(
      name: name,
      brand: brand,
      confidence: 0.8,
      panel: FoodPanel(
        kcal: kcal,
        proteinG: protein,
        carbsG: 1,
        fatG: 10,
        novaGroup: nova,
      ),
    ),
    quantity: quantity,
    unit: unit,
    grams: grams,
    confidence: confidence,
  );
}

void main() {
  late AppDatabase db;
  late MealResolver resolver;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    resolver = MealResolver(db.foodsDao);
  });

  tearDown(() async => db.close());

  Future<int> addFood(
    String name, {
    double kcal = 143,
    double protein = 12.6,
    double? gramsPerPiece,
    String? pieceName,
    String? brand,
    FoodSource source = FoodSource.seed,
  }) {
    return db.foodsDao.upsert(
      FoodsCompanion.insert(
        name: name,
        brand: Value(brand),
        searchKey: name,
        kcal: kcal,
        proteinG: Value(protein),
        gramsPerPiece: Value(gramsPerPiece),
        pieceName: Value(pieceName),
        source: source,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
  }

  group('the write-back rule', () {
    test('a food the model described is stored permanently', () async {
      // CLAUDE.md §4: a given food costs at most one call, ever.
      await resolver.resolve(ParsedMeal(items: [_item(name: 'Kasza gryczana')]));

      final stored = await db.foodsDao.search('Kasza gryczana');
      expect(stored, hasLength(1));
      expect(stored.single.source, FoodSource.ai);
      expect(stored.single.kcal, 150);
    });

    test('a second meal with the same food reuses the stored row', () async {
      await resolver.resolve(ParsedMeal(items: [_item(name: 'Kasza')]));
      final resolved =
          await resolver.resolve(ParsedMeal(items: [_item(name: 'Kasza')]));

      expect(resolved.single.wasAlreadyKnown, isTrue);
      expect(await db.foodsDao.count(), 1);
    });

    test('the model is stored as the weakest source', () async {
      // So a later barcode scan or hand correction is allowed to overwrite it.
      await resolver.resolve(ParsedMeal(items: [_item(name: 'Kasza')]));

      final stored = (await db.foodsDao.search('Kasza')).single;
      expect(stored.source, FoodSource.ai);
      expect(stored.confidence, 0.8);
    });
  });

  group('the library wins over the model', () {
    test('an existing food keeps its own numbers', () async {
      await addFood('Egg, whole', kcal: 143, protein: 12.6);

      final resolved = await resolver.resolve(
        ParsedMeal(items: [_item(name: 'Egg, whole', kcal: 999)]),
      );

      expect(resolved.single.wasAlreadyKnown, isTrue);
      // The model's 999 kcal is discarded; only its reading of the name and
      // the portion survives.
      expect(resolved.single.food.kcal, 143);
      expect(await db.foodsDao.count(), 1);
    });

    test('matching is exact, not fuzzy', () async {
      // A LIKE match is right for a search box, where the user picks from the
      // results. Here nothing would notice "rye bread" silently resolving to
      // "rye bread crackers".
      await addFood('Rye bread crackers', kcal: 400);

      final resolved = await resolver.resolve(
        ParsedMeal(items: [_item(name: 'Rye bread', kcal: 259)]),
      );

      expect(resolved.single.wasAlreadyKnown, isFalse);
      expect(resolved.single.food.kcal, 259);
      expect(await db.foodsDao.count(), 2);
    });

    test('a named brand is not matched against a generic food', () async {
      await addFood('Chocolate');

      final resolved = await resolver.resolve(
        ParsedMeal(items: [_item(name: 'Chocolate', brand: 'Milka')]),
      );

      expect(resolved.single.wasAlreadyKnown, isFalse);
    });

    test('a generic name matches a stored food with no brand', () async {
      await addFood('Egg, whole');

      final resolved = await resolver.resolve(
        ParsedMeal(items: [_item(name: 'Egg, whole')]),
      );

      expect(resolved.single.wasAlreadyKnown, isTrue);
    });
  });

  group('portion resolution', () {
    test('a known piece weight beats the model guess', () async {
      // The device resolves "2 eggs" more reliably than a language model does.
      await addFood('Egg, whole', gramsPerPiece: 50, pieceName: 'egg');

      final resolved = await resolver.resolve(
        ParsedMeal(
          items: [
            _item(name: 'Egg, whole', quantity: 2, grams: 999),
          ],
        ),
      );

      expect(resolved.single.grams, 100);
    });

    test('the model gram figure is used when nothing better exists', () async {
      final resolved = await resolver.resolve(
        ParsedMeal(
          items: [
            _item(
              name: 'Leftover stew',
              quantity: 1,
              unit: PortionUnit.bowl,
              grams: 420,
            ),
          ],
        ),
      );

      expect(resolved.single.grams, 420);
      // Still a guess, so it stays below the exact units' confidence.
      expect(resolved.single.confidence, lessThanOrEqualTo(0.8));
    });

    test('grams and millilitres are taken at face value', () async {
      final resolved = await resolver.resolve(
        ParsedMeal(
          items: [
            _item(quantity: 85, unit: PortionUnit.grams, grams: 999),
          ],
        ),
      );

      expect(resolved.single.grams, 85);
      expect(resolved.single.confidence, 1);
    });

    test('falls back to the unit table when the model gave no grams', () async {
      final resolved = await resolver.resolve(
        ParsedMeal(
          items: [
            _item(name: 'Almonds', quantity: 1, unit: PortionUnit.handful),
          ],
        ),
      );

      final expected = resolvePortion(
        quantity: 1,
        unit: PortionUnit.handful,
        gramsPerPiece: null,
      );
      expect(resolved.single.grams, expected.grams);
      expect(resolved.single.confidence, expected.confidence);
    });

    test('a zero or negative model figure is ignored', () async {
      final resolved = await resolver.resolve(
        ParsedMeal(
          items: [
            _item(name: 'Soup', quantity: 1, unit: PortionUnit.bowl, grams: 0),
          ],
        ),
      );

      expect(resolved.single.grams, greaterThan(0));
    });
  });

  group('a whole meal', () {
    test('resolves every item, mixing known and new foods', () async {
      await addFood('Egg, whole', gramsPerPiece: 50, pieceName: 'egg');

      final resolved = await withClock(
        Clock.fixed(DateTime(2026, 9, 15, 10)),
        () => resolver.resolve(
          ParsedMeal(
            items: [
              _item(name: 'Egg, whole', quantity: 2),
              _item(
                name: 'Rye bread',
                quantity: 1,
                unit: PortionUnit.slice,
                kcal: 259,
                nova: 3,
              ),
            ],
          ),
        ),
      );

      expect(resolved, hasLength(2));
      expect(resolved.first.wasAlreadyKnown, isTrue);
      expect(resolved.last.wasAlreadyKnown, isFalse);
      // One new food written, the known one untouched.
      expect(await db.foodsDao.count(), 2);
    });

    test('an empty meal resolves to nothing', () async {
      expect(await resolver.resolve(const ParsedMeal(items: [])), isEmpty);
      expect(await db.foodsDao.count(), 0);
    });
  });
}
