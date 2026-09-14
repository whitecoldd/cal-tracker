import 'package:drift/drift.dart';

import '../../domain/day.dart';
import '../database.dart';
import '../tables.dart';

part 'tracking_dao.g.dart';

/// Activity, weight and water — everything measured about the body rather than
/// put into it.
///
/// Note that weights are stored and read freely here. The blackout is applied
/// above this layer, at the point a value becomes a *verdict*; the data layer
/// has no business withholding rows.
@DriftAccessor(tables: [ActivityDays, Weights, WaterLogs])
class TrackingDao extends DatabaseAccessor<AppDatabase>
    with _$TrackingDaoMixin {
  TrackingDao(super.db);

  // --- activity ---

  Future<ActivityDay?> activityFor(Day day) =>
      (select(activityDays)..where((a) => a.day.equals(day.value)))
          .getSingleOrNull();

  Stream<ActivityDay?> watchActivity(Day day) =>
      (select(activityDays)..where((a) => a.day.equals(day.value)))
          .watchSingleOrNull();

  Future<List<ActivityDay>> activityInRange(Day from, Day to) =>
      (select(activityDays)
            ..where((a) =>
                a.day.isBiggerOrEqualValue(from.value) &
                a.day.isSmallerOrEqualValue(to.value))
            ..orderBy([(a) => OrderingTerm(expression: a.day)]))
          .get();

  /// Writes a day's activity.
  ///
  /// A manual entry always wins: if the user typed a number for a day, a later
  /// Health Connect sync must not quietly replace it.
  Future<void> upsertActivity(ActivityDaysCompanion activity) async {
    final day = activity.day.value;
    final existing = await activityFor(day);

    if (existing != null &&
        existing.source == ActivitySource.manual &&
        activity.source.value == ActivitySource.healthConnect) {
      return;
    }

    await into(activityDays).insertOnConflictUpdate(activity);
  }

  // --- weight ---

  Future<Weight?> weightFor(Day day) =>
      (select(weights)..where((w) => w.day.equals(day.value)))
          .getSingleOrNull();

  Future<List<Weight>> weightsInRange(Day from, Day to) => (select(weights)
        ..where((w) =>
            w.day.isBiggerOrEqualValue(from.value) &
            w.day.isSmallerOrEqualValue(to.value))
        ..orderBy([(w) => OrderingTerm(expression: w.day)]))
      .get();

  /// The most recent weigh-in on or before [day], if any.
  ///
  /// Used so a week with no weigh-in on its exact boundary can still be
  /// compared against the last known weight rather than reporting nothing.
  Future<Weight?> latestWeightOnOrBefore(Day day) => (select(weights)
        ..where((w) => w.day.isSmallerOrEqualValue(day.value))
        ..orderBy([(w) => OrderingTerm(expression: w.day, mode: OrderingMode.desc)])
        ..limit(1))
      .getSingleOrNull();

  Future<void> upsertWeight(WeightsCompanion weight) =>
      into(weights).insertOnConflictUpdate(weight);

  // --- water ---

  Future<WaterLog?> waterFor(Day day) =>
      (select(waterLogs)..where((w) => w.day.equals(day.value)))
          .getSingleOrNull();

  Stream<WaterLog?> watchWater(Day day) =>
      (select(waterLogs)..where((w) => w.day.equals(day.value)))
          .watchSingleOrNull();

  Future<void> upsertWater(WaterLogsCompanion water) =>
      into(waterLogs).insertOnConflictUpdate(water);
}
