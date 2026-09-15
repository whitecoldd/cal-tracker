import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/remote/remote_food.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = '2026-09-14T10:00:00.000';

FoodsCompanion _byHand(
  String name, {
  String? barcode,
  double kcal = 600,
}) {
  return FoodsCompanion.insert(
    name: name,
    barcode: Value(barcode),
    searchKey: '',
    kcal: kcal,
    source: FoodSource.manual,
    confidence: const Value(1),
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('a food written by hand', () {
    test('is reachable by search like any other', () async {
      await db.foodsDao.upsert(_byHand('Salted almonds'));

      final found = await db.foodsDao.search('salted almonds');
      expect(found.single.name, 'Salted almonds');
      expect(found.single.source, FoodSource.manual);
    });

    test('gets its search key computed for it', () async {
      // The sheet passes an empty key on purpose — upsert owns that rule.
      await db.foodsDao.upsert(_byHand('Salted Almonds!'));

      expect(
        (await db.foodsDao.search('almonds')).single.searchKey,
        'salted almonds',
      );
    });

    test('answers to the barcode whose scan failed', () async {
      await db.foodsDao.upsert(
        _byHand('Salted almonds', barcode: '5941234567890'),
      );

      final byCode = await db.foodsDao.findByBarcode('5941234567890');
      expect(byCode!.name, 'Salted almonds');
    });

    test('outranks what the wider world says later', () async {
      // The claim the whole FoodSource ladder exists for, and which nothing
      // could reach until there was a way to write a food down.
      await db.foodsDao.upsert(
        _byHand('Salted almonds', barcode: '5941234567890', kcal: 600),
      );

      const upstream = RemoteFood(
        name: 'Almonds, salted',
        barcode: '5941234567890',
        kcal: 123,
        source: FoodSource.openFoodFacts,
        confidence: 0.95,
      );
      await db.foodsDao.upsert(upstream.toCompanion(now: clock.now()));

      final stored = await db.foodsDao.findByBarcode('5941234567890');
      expect(stored!.name, 'Salted almonds');
      expect(stored.kcal, 600);
      expect(stored.source, FoodSource.manual);
      // And it enriched rather than duplicated.
      expect(await db.foodsDao.count(), 1);
    });

    test('a hand-written row may still be corrected by hand', () async {
      await db.foodsDao.upsert(
        _byHand('Salted almonds', barcode: '5941234567890', kcal: 600),
      );
      await db.foodsDao.upsert(
        _byHand('Salted almonds', barcode: '5941234567890', kcal: 575),
      );

      final stored = await db.foodsDao.findByBarcode('5941234567890');
      expect(stored!.kcal, 575);
      expect(await db.foodsDao.count(), 1);
    });

    test('enriches a row already known by name', () async {
      await db.foodsDao.upsert(
        FoodsCompanion.insert(
          name: 'Salted almonds',
          searchKey: 'salted almonds',
          kcal: 100,
          source: FoodSource.seed,
          createdAt: _now,
          updatedAt: _now,
        ),
      );
      await db.foodsDao.upsert(_byHand('Salted almonds', kcal: 600));

      expect(await db.foodsDao.count(), 1);
      expect((await db.foodsDao.search('salted almonds')).single.kcal, 600);
    });
  });
}
