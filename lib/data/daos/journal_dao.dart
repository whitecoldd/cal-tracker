import 'package:drift/drift.dart';

import '../../domain/day.dart';
import '../database.dart';
import '../tables.dart';

part 'journal_dao.g.dart';

/// An entry with the food it refers to.
///
/// Every consumer needs both halves, so they are always read together rather
/// than leaving callers to issue a query per row.
class LoggedItem {
  const LoggedItem({required this.entry, required this.food});

  final Entry entry;
  final Food food;

  /// Scale factor from the food's per-100g figures to this portion.
  double get portions => entry.grams / 100.0;

  double get kcal => food.kcal * portions;
  double get proteinG => food.proteinG * portions;
  double get carbsG => food.carbsG * portions;
  double get sugarG => food.sugarG * portions;
  double get fatG => food.fatG * portions;
  double get satFatG => food.satFatG * portions;
  double get fibreG => food.fibreG * portions;
  double get sodiumMg => food.sodiumMg * portions;
  double get alcoholG => food.alcoholG * portions;

  /// Glycemic load for this portion: GI weighted by the carbohydrate actually
  /// eaten. Null where the food has no meaningful GI.
  double? get glycemicLoad {
    final gi = food.glycemicIndex;
    if (gi == null) return null;
    return gi * carbsG / 100.0;
  }
}

/// Reads and writes logged food.
@DriftAccessor(tables: [Entries, Foods])
class JournalDao extends DatabaseAccessor<AppDatabase> with _$JournalDaoMixin {
  JournalDao(super.db);

  /// Everything logged on [day], oldest first.
  Stream<List<LoggedItem>> watchDay(Day day) {
    final query = select(entries).join([
      innerJoin(foods, foods.id.equalsExp(entries.foodId)),
    ])
      ..where(entries.day.equals(day.value))
      ..orderBy([OrderingTerm(expression: entries.createdAt)]);

    return query.watch().map(
          (rows) => rows
              .map((r) => LoggedItem(
                    entry: r.readTable(entries),
                    food: r.readTable(foods),
                  ))
              .toList(),
        );
  }

  /// A one-shot read of [day].
  ///
  /// A plain query rather than the first event of [watchDay]: there is no
  /// reason to build and tear down a stream for a single read, and a stream
  /// needs an event loop that a widget test's fake async does not turn.
  Future<List<LoggedItem>> forDay(Day day) => forRange(day, day);

  /// Everything logged across an inclusive day range — the week's aggregate.
  Future<List<LoggedItem>> forRange(Day from, Day to) async {
    final query = select(entries).join([
      innerJoin(foods, foods.id.equalsExp(entries.foodId)),
    ])
      ..where(
        entries.day.isBiggerOrEqualValue(from.value) &
            entries.day.isSmallerOrEqualValue(to.value),
      )
      ..orderBy([OrderingTerm(expression: entries.day)]);

    final rows = await query.get();
    return rows
        .map((r) => LoggedItem(
              entry: r.readTable(entries),
              food: r.readTable(foods),
            ))
        .toList();
  }

  /// Days on which anything at all was logged, within an inclusive range.
  /// Used for the logging streak that drives Axii and Adrenaline.
  Future<Set<Day>> loggedDaysIn(Day from, Day to) async {
    final query = selectOnly(entries, distinct: true)
      ..addColumns([entries.day])
      ..where(
        entries.day.isBiggerOrEqualValue(from.value) &
            entries.day.isSmallerOrEqualValue(to.value),
      );

    final rows = await query.get();
    // `selectOnly` reads the raw column, so the Day converter is not applied.
    return rows.map((r) => Day(r.read(entries.day)!)).toSet();
  }

  /// How many times each food has ever been logged, keyed by food id.
  ///
  /// One grouped query rather than a count per food: the Bestiary shows the
  /// whole library at once, and a query per row would make the screen's cost
  /// grow with the size of the collection it exists to celebrate.
  Future<Map<int, int>> timesEatenByFood() async {
    final count = entries.id.count();
    final rows = await (selectOnly(entries)
          ..addColumns([entries.foodId, count])
          ..groupBy([entries.foodId]))
        .get();

    return {
      for (final row in rows)
        row.read(entries.foodId)!: row.read(count) ?? 0,
    };
  }

  /// The day each food was first logged, keyed by food id.
  ///
  /// The Bestiary is a collection, and a collection wants to know when each
  /// entry was found.
  Future<Map<int, Day>> firstSeenByFood() async {
    final earliest = entries.day.min();
    final rows = await (selectOnly(entries)
          ..addColumns([entries.foodId, earliest])
          ..groupBy([entries.foodId]))
        .get();

    return {
      for (final row in rows)
        if (row.read(earliest) != null)
          row.read(entries.foodId)!: Day(row.read(earliest)!),
    };
  }

  Future<int> add(EntriesCompanion entry) => into(entries).insert(entry);

  Future<bool> updateEntry(Entry entry) => update(entries).replace(entry);

  Future<int> remove(int id) =>
      (delete(entries)..where((e) => e.id.equals(id))).go();
}
