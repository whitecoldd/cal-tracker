import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../domain/activity.dart';
import '../../domain/day.dart';
import '../daos/tracking_dao.dart';
import '../database.dart';
import '../tables.dart';
import 'step_reader.dart';

/// What a sync did, so the UI can say something specific.
class SyncResult {
  const SyncResult({
    required this.availability,
    required this.granted,
    this.daysWritten = 0,
    this.daysKept = 0,
  });

  final HealthAvailability availability;
  final bool granted;

  /// Days whose figures were updated from the device.
  final int daysWritten;

  /// Days left alone because the user had typed them by hand.
  final int daysKept;

  bool get ok => availability == HealthAvailability.ready && granted;
}

/// Pulls movement from the platform into `activity_days`.
///
/// The interesting rule is [mergeActivity]: a manual entry always wins. The
/// user typed a number precisely because the device was wrong, and a sync that
/// overwrote it would make the override pointless.
class ActivitySync {
  const ActivitySync({required StepReader reader, required TrackingDao tracking})
      : _reader = reader,
        _tracking = tracking;

  final StepReader _reader;
  final TrackingDao _tracking;

  /// How far back a routine sync looks.
  ///
  /// Health Connect back-fills: a phone that was off, or a watch that synced
  /// late, can add steps to a day that is already past. Re-reading a week
  /// costs one query and catches all of it.
  static const int lookbackDays = 7;

  Future<SyncResult> syncRecent() async {
    final today = Day.from(clock.now());
    return sync(from: today.addDays(-lookbackDays), to: today);
  }

  Future<SyncResult> sync({required Day from, required Day to}) async {
    final availability = await _reader.availability();
    if (availability != HealthAvailability.ready) {
      return SyncResult(availability: availability, granted: false);
    }

    if (!await _reader.hasPermission()) {
      return SyncResult(availability: availability, granted: false);
    }

    final measured = await _reader.read(from: from, to: to);

    var written = 0;
    var kept = 0;

    for (final day in measured) {
      final existing = await _tracking.activityFor(day.day);

      // The DAO enforces this too, but deciding it here means the result can
      // say *why* a day was skipped rather than silently reporting a write.
      if (existing != null && existing.source == ActivitySource.manual) {
        kept++;
        continue;
      }

      await _tracking.upsertActivity(
        ActivityDaysCompanion.insert(
          day: day.day,
          steps: Value(day.steps),
          distanceM: Value(day.distanceM),
          activeKcal: Value(day.activeKcal),
          source: ActivitySource.healthConnect,
          updatedAt: clock.now().toIso8601String(),
        ),
      );
      written++;
    }

    return SyncResult(
      availability: availability,
      granted: true,
      daysWritten: written,
      daysKept: kept,
    );
  }

  /// Asks for permission, then syncs if it was given.
  Future<SyncResult> connect() async {
    final availability = await _reader.availability();
    if (availability != HealthAvailability.ready) {
      return SyncResult(availability: availability, granted: false);
    }

    final granted =
        await _reader.hasPermission() || await _reader.requestPermission();
    if (!granted) {
      return SyncResult(availability: availability, granted: false);
    }

    return syncRecent();
  }

  /// Writes a day the user typed themselves.
  ///
  /// Distance is derived from stride when they gave only a step count, which
  /// is the usual case — people know roughly how many steps they took and
  /// never how many metres.
  Future<void> recordManual({
    required Day day,
    required int steps,
    required double strideCm,
    double? distanceM,
  }) {
    return _tracking.upsertActivity(
      ActivityDaysCompanion.insert(
        day: day,
        steps: Value(steps),
        distanceM: Value(
          distanceM ?? distanceForSteps(steps: steps, strideCm: strideCm),
        ),
        // Deliberately null. A typed step count says nothing about energy, and
        // inventing one here would put a guess into the week's expenditure.
        activeKcal: const Value(null),
        source: ActivitySource.manual,
        updatedAt: clock.now().toIso8601String(),
      ),
    );
  }

  /// Turns a stored row back into the domain type.
  static DayActivity fromRow(ActivityDay row) => DayActivity(
        day: row.day,
        steps: row.steps,
        distanceM: row.distanceM,
        activeKcal: row.activeKcal,
        isManual: row.source == ActivitySource.manual,
      );
}
