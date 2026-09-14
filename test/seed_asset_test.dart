import 'dart:convert';
import 'dart:io';

import 'package:cal_tracker/data/daos/foods_dao.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/seed_loader.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates the shipped seed table itself, not a fixture.
///
/// These numbers are typed by hand, so the point is to catch the mistakes that
/// hand-typed nutrition data actually makes: macros that do not add up to the
/// stated energy, sugar exceeding total carbohydrate, a glycemic index put on a
/// food with no carbohydrate.
void main() {
  late Map<String, dynamic> decoded;
  late List<Map<String, dynamic>> items;

  setUpAll(() {
    final raw = File(SeedLoader.assetPath).readAsStringSync();
    decoded = json.decode(raw) as Map<String, dynamic>;
    items = (decoded['foods'] as List<dynamic>).cast<Map<String, dynamic>>();
  });

  double n(Map<String, dynamic> f, String key) =>
      (f[key] as num?)?.toDouble() ?? 0;

  test('is a versioned, non-trivial table', () {
    expect(decoded['version'], 1);
    expect(items.length, greaterThan(100));
  });

  test('every food has a unique, non-empty name', () {
    final names = items.map((f) => f['name'] as String).toList();
    expect(names.every((s) => s.trim().isNotEmpty), isTrue);
    expect(names.toSet(), hasLength(names.length));
  });

  test('every food normalises to a distinct search key', () {
    // Two foods sharing a key would silently collapse into one row on load.
    final keys = items
        .map((f) => FoodsDao.searchKeyFor(f['name'] as String))
        .toList();
    expect(keys.toSet(), hasLength(keys.length));
  });

  test('macros are consistent with the stated energy', () {
    for (final f in items) {
      final stated = n(f, 'kcal');
      if (stated <= 20) continue; // rounding dominates at trace energies

      final implied = n(f, 'protein') * 4 +
          n(f, 'carbs') * 4 +
          n(f, 'fat') * 9 +
          n(f, 'alcohol') * 7;

      // Atwater factors are approximations, and fibre and polyols muddy them,
      // so allow real slack — this is a typo check, not a lab assay.
      expect(
        (implied - stated).abs(),
        lessThanOrEqualTo(stated * 0.28 > 35 ? stated * 0.28 : 35),
        reason: '${f['name']}: macros imply $implied kcal, table says $stated',
      );
    }
  });

  test('sugar never exceeds carbohydrate, added sugar never exceeds sugar', () {
    for (final f in items) {
      final name = f['name'];
      expect(n(f, 'sugar'), lessThanOrEqualTo(n(f, 'carbs') + 0.5),
          reason: '$name');
      if (f.containsKey('addedSugar')) {
        expect(n(f, 'addedSugar'), lessThanOrEqualTo(n(f, 'sugar') + 0.5),
            reason: '$name');
      }
    }
  });

  test('saturated fat never exceeds total fat', () {
    for (final f in items) {
      expect(n(f, 'satFat'), lessThanOrEqualTo(n(f, 'fat') + 0.1),
          reason: '${f['name']}');
    }
  });

  test('glycemic index is plausible and only set on carbohydrate foods', () {
    for (final f in items) {
      if (!f.containsKey('gi')) continue;
      final gi = n(f, 'gi');
      expect(gi, greaterThan(0), reason: '${f['name']}');
      expect(gi, lessThanOrEqualTo(110), reason: '${f['name']}');
      expect(n(f, 'carbs'), greaterThanOrEqualTo(2),
          reason: '${f['name']}: GI on a food with no carbohydrate');
    }
  });

  test('NOVA groups are in range', () {
    for (final f in items) {
      if (!f.containsKey('nova')) continue;
      expect(n(f, 'nova'), inInclusiveRange(1, 4), reason: '${f['name']}');
    }
  });

  test('a piece weight always comes with a name for the piece', () {
    for (final f in items) {
      expect(
        f.containsKey('gramsPerPiece'),
        f.containsKey('pieceName'),
        reason: '${f['name']}: piece weight and piece name must travel together',
      );
    }
  });

  test('loads into the database and is searchable', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final raw = File(SeedLoader.assetPath).readAsStringSync();
    final loaded = await SeedLoader(db.foodsDao).loadFromJson(raw);

    expect(loaded, items.length);
    expect(await db.foodsDao.count(), items.length);

    // Spot-check the kind of lookup the Journal will actually do.
    final chicken = await db.foodsDao.search('chicken breast');
    expect(chicken, isNotEmpty);
    expect(chicken.first.proteinG, greaterThan(20));
    expect(chicken.first.source, FoodSource.seed);

    final egg = (await db.foodsDao.search('egg whole')).first;
    expect(egg.gramsPerPiece, 50);
    expect(egg.pieceName, 'egg');
  });
}
