import 'package:drift/drift.dart';

import '../../domain/day.dart';
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

  /// Unlocks an achievement, ignoring a repeat award for the same week.
  Future<void> unlock(AchievementsCompanion achievement) async {
    await into(achievements)
        .insert(achievement, mode: InsertMode.insertOrIgnore);
  }
}
