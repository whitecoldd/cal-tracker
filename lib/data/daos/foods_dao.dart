import 'package:drift/drift.dart';

import '../../domain/food_query.dart';
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
  ///
  /// The rule itself lives in `domain/food_query.dart`, so a stored key and a
  /// typed query cannot be normalised two different ways. Changing it there is
  /// a migration: every key already on a device was written by the old one.
  static String searchKeyFor(String name, [String? brand]) =>
      normaliseSearchText(name, brand);

  Future<Food?> findByBarcode(String barcode) =>
      (select(foods)..where((f) => f.barcode.equals(barcode)))
          .getSingleOrNull();

  Future<Food?> findById(int id) =>
      (select(foods)..where((f) => f.id.equals(id))).getSingleOrNull();

  /// How many rows are considered before ranking.
  ///
  /// Generous: the whole point of ranking in Dart is that the interesting
  /// ordering cannot be expressed in the SQL, so the SQL must not be what
  /// decides which rows are seen. The library is a few hundred rows.
  static const int _candidateCap = 200;

  /// Local search.
  Future<List<Food>> search(String query, {int limit = 25}) =>
      searchFor(parseFoodQuery(query), limit: limit);

  /// Local search for an already-parsed query.
  ///
  /// Every term must appear, in any order — which is what makes "white monster"
  /// find `Monster Energy Ultra White`. The old query was a single `LIKE` over
  /// the whole string, so a multi-word search only ever matched words that were
  /// adjacent and in the order typed.
  ///
  /// The `WHERE` is N ANDed LIKEs so SQLite does the pruning; the *ranking* is
  /// done in Dart. Two reasons for the split. The tier rule is a domain rule
  /// and has to be testable without a database in the room. And the ordering
  /// this replaces is the cautionary tale: its comment promised ordering by
  /// source quality and there was no ordering term on `source` at all, so an AI
  /// row at confidence 0.95 outranked a seed row at 0.9 — the exact inversion
  /// the comment said could not happen. A comparator can be asserted on.
  Future<List<Food>> searchFor(FoodQuery query, {int limit = 25}) async {
    if (query.isEmpty) return const [];

    // Terms are [a-z0-9] after normalisation, so `%` and `_` cannot appear in
    // one; drift binds the pattern as a variable in any case. Nothing here
    // needs "hardening".
    final candidates = await (select(foods)
          ..where(
            (f) => query.terms
                .map((t) => f.searchKey.like('%$t%'))
                .reduce((a, b) => a & b),
          )
          ..orderBy([
            (f) => OrderingTerm(expression: f.source, mode: OrderingMode.desc),
            (f) =>
                OrderingTerm(expression: f.confidence, mode: OrderingMode.desc),
            (f) => OrderingTerm(expression: f.name),
          ])
          ..limit(_candidateCap))
        .get();

    final ranked = candidates
        .map((food) => (food: food, tier: matchTier(food.searchKey, query)))
        .where((row) => row.tier != null)
        .toList()
      ..sort((a, b) {
        final byTier = a.tier!.compareTo(b.tier!);
        if (byTier != 0) return byTier;
        // A food the user corrected by hand beats a barcode result, and both
        // beat an AI estimate, so a good answer already on the device is never
        // passed over.
        final bySource = b.food.source.index.compareTo(a.food.source.index);
        if (bySource != 0) return bySource;
        final byConfidence = b.food.confidence.compareTo(a.food.confidence);
        if (byConfidence != 0) return byConfidence;
        return a.food.name.compareTo(b.food.name);
      });

    return [for (final row in ranked.take(limit)) row.food];
  }

  /// Every food, newest first. A one-shot read.
  ///
  /// Beside [watchAll] rather than `watchAll().first`: building and tearing
  /// down a query stream for a single read schedules a zero-duration timer on
  /// cancel, which the test binding reports as a leak — and there was never a
  /// reason to open a stream you immediately close. Same lesson as
  /// `JournalDao.forDay` in T4.
  Future<List<Food>> all() => (select(foods)
        ..orderBy([
          (f) => OrderingTerm(expression: f.createdAt, mode: OrderingMode.desc),
        ]))
      .get();

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
