import 'package:drift/drift.dart';

import '../../domain/day.dart';
import '../../domain/mutagens.dart';
import '../database.dart';
import '../tables.dart';

part 'weeks_dao.g.dart';

/// Closed weeks and the perks they earned.
@DriftAccessor(tables: [Weeks, Achievements])
class WeeksDao extends DatabaseAccessor<AppDatabase> with _$WeeksDaoMixin {
  WeeksDao(super.db);

  Future<Week?> forWeekStart(Day weekStart) =>
      (select(weeks)..where((w) => w.weekStart.equals(weekStart.value)))
          .getSingleOrNull();

  /// Every closed week, newest first. A one-shot read.
  ///
  /// See [FoodsDao.all] for why this exists beside the stream.
  Future<List<Week>> history() => (select(weeks)
        ..where((w) => w.revealed.equals(true))
        ..orderBy([
          (w) => OrderingTerm(expression: w.weekStart, mode: OrderingMode.desc),
        ]))
      .get();

  /// Every closed week, newest first.
  Stream<List<Week>> watchHistory() => (select(weeks)
        ..where((w) => w.revealed.equals(true))
        ..orderBy([
          (w) => OrderingTerm(expression: w.weekStart, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<void> upsert(WeeksCompanion week) =>
      into(weeks).insertOnConflictUpdate(week);

  /// Freezes a week's summary.
  ///
  /// Once written, a week is history: later changes to the scoring maths must
  /// not rewrite what the user was already told.
  Future<void> seal(
    Day weekStart, {
    required String summaryJson,
    String? narrative,
    int xpAwarded = 0,
  }) async {
    await (update(weeks)..where((w) => w.weekStart.equals(weekStart.value)))
        .write(
      WeeksCompanion(
        revealed: const Value(true),
        summaryJson: Value(summaryJson),
        narrative: Value(narrative),
        xpAwarded: Value(xpAwarded),
      ),
    );
  }

  // --- achievements ---

  Stream<List<Achievement>> watchAchievements() => (select(achievements)
        ..orderBy([
          (a) => OrderingTerm(expression: a.unlockedAt, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<List<Achievement>> allAchievements() => select(achievements).get();

  /// The mutagens one week earned.
  ///
  /// Keyed by `weekStart` rather than read from the whole table, which is the
  /// difference between a perk and a permanent upgrade: a bonus computed from
  /// every achievement ever unlocked grows until it hits the stacking cap and
  /// then never moves again. It is also the only version that is *stable* —
  /// re-reading an old week has to give the answer it gave at the time, and
  /// "everything in the table right now" gives a different one every week.
  ///
  /// A code this build no longer recognises is dropped rather than shown as a
  /// blank, the same rule the trophy case uses.
  Future<Set<Mutagen>> mutagensForWeek(Day weekStart) async {
    final rows = await (select(achievements)
          ..where((a) => a.weekStart.equals(weekStart.value)))
        .get();

    return {
      for (final row in rows) ?Mutagen.byCode(row.code),
    };
  }

  /// Unlocks an achievement, ignoring a repeat award for the same week.
  Future<void> unlock(AchievementsCompanion achievement) async {
    await into(achievements)
        .insert(achievement, mode: InsertMode.insertOrIgnore);
  }
}
