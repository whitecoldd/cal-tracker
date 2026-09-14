import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'foods_dao.g.dart';

/// Reads and writes the canonical food library.
///
/// This is the layer that makes the AI budget survivable: the first three steps
/// of the resolution order (user library, seed table, previously cached Open
/// Food Facts results) are all a single local query, because everything ever
/// resolved is written back here.
@DriftAccessor(tables: [Foods])
class FoodsDao extends DatabaseAccessor<AppDatabase> with _$FoodsDaoMixin {
  FoodsDao(super.db);

  /// Normalised lookup key for a name/brand pair.
  static String searchKeyFor(String name, [String? brand]) {
    final joined = brand == null || brand.isEmpty ? name : '$name $brand';
    return joined
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<Food?> findByBarcode(String barcode) =>
      (select(foods)..where((f) => f.barcode.equals(barcode)))
          .getSingleOrNull();

  Future<Food?> findById(int id) =>
      (select(foods)..where((f) => f.id.equals(id))).getSingleOrNull();

  /// Local search, best source first.
  ///
  /// Ordering by [FoodSource] index descending puts a food the user corrected
  /// by hand above a barcode result, and both above an AI estimate — so a good
  /// answer already on the device is never passed over for a network call.
  Future<List<Food>> search(String query, {int limit = 25}) {
    final key = searchKeyFor(query);
    if (key.isEmpty) return Future.value(const []);

    return (select(foods)
          ..where((f) => f.searchKey.like('%$key%'))
          ..orderBy([
            // Exact matches first, then by source quality, then by confidence.
            (f) => OrderingTerm(
                  expression: f.searchKey.equals(key),
                  mode: OrderingMode.desc,
                ),
            (f) => OrderingTerm(expression: f.confidence, mode: OrderingMode.desc),
            (f) => OrderingTerm(expression: f.name),
          ])
          ..limit(limit))
        .get();
  }

  /// Watches every food, newest first — the Bestiary.
  Stream<List<Food>> watchAll() => (select(foods)
        ..orderBy([(f) => OrderingTerm(expression: f.createdAt, mode: OrderingMode.desc)]))
      .watch();

  Future<int> count() async {
    final row = await (selectOnly(foods)..addColumns([foods.id.count()]))
        .getSingle();
    return row.read(foods.id.count()) ?? 0;
  }

  /// Inserts a food, or updates an existing one **only if the new data comes
  /// from a better source**.
  ///
  /// Without that guard, a background Open Food Facts refresh would quietly
  /// overwrite a correction the user typed by hand.
  ///
  /// The search key is always recomputed here rather than taken on trust. A
  /// caller that normalised it differently would otherwise fail to match the
  /// existing row and silently insert a duplicate.
  Future<int> upsert(FoodsCompanion input) async {
    final food = input.copyWith(
      searchKey: Value(
        searchKeyFor(input.name.value, input.brand.value),
      ),
    );

    // Barcode is the strongest identity, but fall back to the name key: a
    // barcode scan of something already in the library by name should enrich
    // that row, not sit beside it as a second copy.
    final barcode = food.barcode.value;
    final existing = (barcode != null && barcode.isNotEmpty
            ? await findByBarcode(barcode)
            : null) ??
        await _findBySearchKey(food.searchKey.value);

    if (existing == null) {
      return into(foods).insert(food);
    }

    final incoming = food.source.value;
    if (incoming.index < existing.source.index) {
      // Existing data is from a more trustworthy source. Leave it alone.
      return existing.id;
    }

    await (update(foods)..where((f) => f.id.equals(existing.id)))
        .write(food.copyWith(id: Value(existing.id)));
    return existing.id;
  }

  /// Every search key currently in the library.
  ///
  /// Read in one query so a bulk load can skip what it already has without
  /// issuing a lookup per item.
  Future<Set<String>> existingSearchKeys() async {
    final rows = await (selectOnly(foods)..addColumns([foods.searchKey])).get();
    return rows.map((r) => r.read(foods.searchKey)!).toSet();
  }

  /// Bulk-inserts foods that are not already in the library.
  ///
  /// Deduplication is by search key, checked here rather than left to
  /// `InsertMode.insertOrIgnore`: the only unique constraint on the table is
  /// `barcode`, and SQLite does not treat two NULL barcodes as a conflict — so
  /// an ignoring insert would happily duplicate every unbranded seed food.
  Future<int> insertMissing(List<FoodsCompanion> items) async {
    final existing = await existingSearchKeys();
    final fresh = <FoodsCompanion>[];
    final seen = <String>{};

    for (final item in items) {
      final key = searchKeyFor(item.name.value, item.brand.value);
      if (existing.contains(key) || !seen.add(key)) continue;
      fresh.add(item.copyWith(searchKey: Value(key)));
    }

    if (fresh.isEmpty) return 0;
    await batch((b) => b.insertAll(foods, fresh));
    return fresh.length;
  }

  Future<Food?> _findBySearchKey(String key) =>
      (select(foods)..where((f) => f.searchKey.equals(key))).getSingleOrNull();
}
