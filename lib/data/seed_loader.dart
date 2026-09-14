import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'daos/foods_dao.dart';
import 'database.dart';
import 'tables.dart';

/// Loads the bundled table of generic whole foods into the food library.
///
/// This is step two of the resolution order (CLAUDE.md §4): with a few hundred
/// staples already on the device, most ordinary logging never reaches the
/// network at all, let alone the model. Branded products are not seeded — those
/// come from Open Food Facts by barcode at runtime.
class SeedLoader {
  const SeedLoader(this._foods);

  final FoodsDao _foods;

  static const String assetPath = 'assets/data/seed_foods.json';

  /// Loads any seed foods the library does not already have.
  ///
  /// Returns how many were inserted. Safe to call on every launch and safe to
  /// call after the seed file grows: existing rows, including ones the user has
  /// corrected, are left untouched.
  Future<int> ensureLoaded() async {
    final raw = await rootBundle.loadString(assetPath);
    return loadFromJson(raw);
  }

  /// Parses and inserts seed JSON. Exposed separately so tests can feed it a
  /// fixture without touching the asset bundle.
  Future<int> loadFromJson(String raw) async {
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final items = (decoded['foods'] as List<dynamic>).cast<Map<String, dynamic>>();
    final now = clock.now().toIso8601String();

    final companions = items.map((f) => _toCompanion(f, now)).toList();
    return _foods.insertMissing(companions);
  }

  FoodsCompanion _toCompanion(Map<String, dynamic> f, String now) {
    double num_(String key, [double fallback = 0]) =>
        (f[key] as num?)?.toDouble() ?? fallback;
    int? int_(String key) => (f[key] as num?)?.toInt();

    final name = f['name'] as String;

    return FoodsCompanion.insert(
      name: name,
      searchKey: FoodsDao.searchKeyFor(name),
      kcal: num_('kcal'),
      proteinG: Value(num_('protein')),
      carbsG: Value(num_('carbs')),
      sugarG: Value(num_('sugar')),
      // Absent means "no free sugars", which for a whole food is a fact rather
      // than a gap — the generator only omits it where that is true.
      addedSugarG: Value(num_('addedSugar', 0)),
      fatG: Value(num_('fat')),
      satFatG: Value(num_('satFat')),
      fibreG: Value(num_('fibre')),
      sodiumMg: Value(num_('sodiumMg')),
      alcoholG: Value(num_('alcohol')),
      glycemicIndex: Value(int_('gi')),
      novaGroup: Value(int_('nova')),
      gramsPerPiece: Value((f['gramsPerPiece'] as num?)?.toDouble()),
      pieceName: Value(f['pieceName'] as String?),
      source: FoodSource.seed,
      confidence: const Value(0.9),
      createdAt: now,
      updatedAt: now,
    );
  }
}
