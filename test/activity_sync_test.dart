import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/health/activity_sync.dart';
import 'package:cal_tracker/data/health/step_reader.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/activity.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

const _monday = Day(20260914);
const _now = '2026-09-15T10:00:00.000';

/// Stands in for Health Connect.
///
/// No test can talk to the real thing: it is another app, reached over a
/// platform channel, and a test that needed it would need a device with Health
/// Connect installed and populated. The merge rules are the part worth
/// testing, and they do not need any of that.
class _FakeReader implements StepReader {
  _FakeReader({
    this.available = HealthAvailability.ready,
    this.permitted = true,
    this.grantOnRequest = true,
    this.days = const [],
  });

  HealthAvailability available;
  bool permitted;
  bool grantOnRequest;
  List<DayActivity> days;

  int readCalls = 0;
  int requestCalls = 0;
  int installPrompts = 0;

  @override
  Future<HealthAvailability> availability() async => available;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async {
    requestCalls++;
    permitted = grantOnRequest;
    return grantOnRequest;
  }

  @override
  Future<void> promptInstall() async => installPrompts++;

  @override
  Future<List<DayActivity>> read({required Day from, required Day to}) async {
    readCalls++;
    return days;
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ActivitySync syncWith(_FakeReader reader) =>
      ActivitySync(reader: reader, tracking: db.trackingDao);

  Future<void> storeManual(Day day, int steps) {
    return db.trackingDao.upsertActivity(
      ActivityDaysCompanion.insert(
        day: day,
        steps: Value(steps),
        distanceM: const Value(0),
        source: ActivitySource.manual,
        updatedAt: _now,
      ),
    );
  }

  group('a successful sync', () {
    test('writes every measured day', () async {
      final reader = _FakeReader(days: [
        const DayActivity(day: _monday, steps: 8200, distanceM: 6100, activeKcal: 310),
        DayActivity(day: _monday.addDays(1), steps: 11000, distanceM: 8000),
      ]);

      final result = await syncWith(reader).sync(
        from: _monday,
        to: _monday.addDays(6),
      );

      expect(result.ok, isTrue);
      expect(result.daysWritten, 2);

      final stored = await db.trackingDao.activityFor(_monday);
      expect(stored!.steps, 8200);
      expect(stored.source, ActivitySource.healthConnect);
      // Stored but never rendered — it is a term of expenditure.
      expect(stored.activeKcal, 310);
    });

    test('a later sync updates a day that was back-filled', () async {
      // Health Connect back-fills: a watch that synced late can add steps to a
      // day already past, so re-reading is a correction rather than a clash.
      final reader = _FakeReader(
        days: [const DayActivity(day: _monday, steps: 4000)],
      );
      await syncWith(reader).sync(from: _monday, to: _monday);

      reader.days = [const DayActivity(day: _monday, steps: 9500)];
      await syncWith(reader).sync(from: _monday, to: _monday);

      final stored = await db.trackingDao.activityFor(_monday);
      expect(stored!.steps, 9500);
    });

    test('a day the device never saw is left absent, not zeroed', () async {
      // Writing a zero would claim the user did not move; an absent day says
      // the device did not see it, which is a different thing.
      final reader = _FakeReader(
        days: [const DayActivity(day: _monday, steps: 8200)],
      );

      await syncWith(reader).sync(from: _monday, to: _monday.addDays(6));

      expect(await db.trackingDao.activityFor(_monday.addDays(3)), isNull);
    });
  });

  group('the manual override', () {
    test('a typed day survives a sync', () async {
      await storeManual(_monday, 12000);

      final reader = _FakeReader(
        days: [const DayActivity(day: _monday, steps: 3000)],
      );
      final result = await syncWith(reader).sync(from: _monday, to: _monday);

      final stored = await db.trackingDao.activityFor(_monday);
      expect(stored!.steps, 12000, reason: 'the typed figure must win');
      expect(stored.source, ActivitySource.manual);
      expect(result.daysKept, 1);
      expect(result.daysWritten, 0);
    });

    test('recordManual derives distance from stride', () async {
      await syncWith(_FakeReader()).recordManual(
        day: _monday,
        steps: 10000,
        strideCm: 74,
      );

      final stored = await db.trackingDao.activityFor(_monday);
      expect(stored!.distanceM, closeTo(7400, 0.001));
      expect(stored.source, ActivitySource.manual);
    });

    test('recordManual takes a stated distance over the derived one', () async {
      await syncWith(_FakeReader()).recordManual(
        day: _monday,
        steps: 10000,
        strideCm: 74,
        distanceM: 9000,
      );

      expect((await db.trackingDao.activityFor(_monday))!.distanceM, 9000);
    });

    test('a typed day carries no energy figure', () async {
      // A step count says nothing about energy, and inventing one would put a
      // guess into the week's expenditure.
      await syncWith(_FakeReader()).recordManual(
        day: _monday,
        steps: 10000,
        strideCm: 74,
      );

      expect((await db.trackingDao.activityFor(_monday))!.activeKcal, isNull);
    });
  });

  group('when movement cannot be read', () {
    test('reports Health Connect missing without touching the database',
        () async {
      final reader = _FakeReader(available: HealthAvailability.notInstalled);

      final result = await syncWith(reader).syncRecent();

      expect(result.ok, isFalse);
      expect(result.availability, HealthAvailability.notInstalled);
      expect(reader.readCalls, 0);
    });

    test('reports a refused permission', () async {
      final reader = _FakeReader(permitted: false);

      final result = await syncWith(reader).syncRecent();

      expect(result.ok, isFalse);
      expect(result.granted, isFalse);
      expect(reader.readCalls, 0);
    });

    test('an unsupported platform is not an error state', () async {
      // The web build has no Health Connect. Manual entry still works, so this
      // is a fact about the device rather than a failure.
      final reader = _FakeReader(available: HealthAvailability.unsupported);

      final result = await syncWith(reader).syncRecent();

      expect(result.availability, HealthAvailability.unsupported);
      expect(result.ok, isFalse);
    });
  });

  group('connecting', () {
    test('asks for permission, then syncs', () async {
      final reader = _FakeReader(
        permitted: false,
        days: [const DayActivity(day: _monday, steps: 7000)],
      );

      final result = await syncWith(reader).connect();

      expect(reader.requestCalls, 1);
      expect(result.ok, isTrue);
      expect(result.daysWritten, 1);
    });

    test('does not ask again when permission already exists', () async {
      final reader = _FakeReader(days: [const DayActivity(day: _monday, steps: 700)]);

      await syncWith(reader).connect();

      expect(reader.requestCalls, 0);
    });

    test('stops cleanly when permission is refused', () async {
      final reader = _FakeReader(permitted: false, grantOnRequest: false);

      final result = await syncWith(reader).connect();

      expect(result.granted, isFalse);
      expect(reader.readCalls, 0);
    });
  });

  group('the lookback window', () {
    test('re-reads a week, because Health Connect back-fills', () async {
      final reader = _FakeReader();

      await withClock(Clock.fixed(DateTime(2026, 9, 15, 12)), () async {
        await syncWith(reader).syncRecent();
      });

      expect(reader.readCalls, 1);
      expect(ActivitySync.lookbackDays, greaterThanOrEqualTo(7));
    });
  });

  group('folding raw points into days', () {
    HealthDataPoint point(
      HealthDataType type,
      num value,
      DateTime from,
    ) {
      return HealthDataPoint(
        uuid: '$type-$from-$value',
        value: NumericHealthValue(numericValue: value),
        type: type,
        unit: HealthDataUnit.COUNT,
        dateFrom: from,
        dateTo: from.add(const Duration(minutes: 10)),
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'test',
        sourceId: 'test',
        sourceName: 'test',
      );
    }

    test('sums many short intervals into one day', () {
      final folded = HealthConnectReader.foldPoints([
        point(HealthDataType.STEPS, 1200, DateTime(2026, 9, 14, 8)),
        point(HealthDataType.STEPS, 3400, DateTime(2026, 9, 14, 13)),
        point(HealthDataType.STEPS, 900, DateTime(2026, 9, 14, 19)),
      ]);

      expect(folded, hasLength(1));
      expect(folded.single.day, _monday);
      expect(folded.single.steps, 5500);
    });

    test('separates days and keeps them in order', () {
      final folded = HealthConnectReader.foldPoints([
        point(HealthDataType.STEPS, 500, DateTime(2026, 9, 16, 9)),
        point(HealthDataType.STEPS, 800, DateTime(2026, 9, 14, 9)),
      ]);

      expect(folded.map((d) => d.day), [_monday, const Day(20260916)]);
    });

    test('combines the three data types for one day', () {
      final folded = HealthConnectReader.foldPoints([
        point(HealthDataType.STEPS, 8000, DateTime(2026, 9, 14, 9)),
        point(HealthDataType.DISTANCE_DELTA, 6000, DateTime(2026, 9, 14, 9)),
        point(
          HealthDataType.ACTIVE_ENERGY_BURNED,
          280,
          DateTime(2026, 9, 14, 9),
        ),
      ]);

      expect(folded.single.steps, 8000);
      expect(folded.single.distanceM, 6000);
      expect(folded.single.activeKcal, 280);
    });

    test('attributes an interval to the day it started', () {
      // A walk crossing midnight is rare; splitting it proportionally would be
      // more correct and less predictable, and the user reads these against a
      // calendar day they remember.
      final folded = HealthConnectReader.foldPoints([
        point(HealthDataType.STEPS, 400, DateTime(2026, 9, 14, 23, 55)),
      ]);

      expect(folded.single.day, _monday);
    });

    test('ignores a negative or nonsensical reading', () {
      final folded = HealthConnectReader.foldPoints([
        point(HealthDataType.STEPS, -500, DateTime(2026, 9, 14, 9)),
        point(HealthDataType.STEPS, 900, DateTime(2026, 9, 14, 10)),
      ]);

      expect(folded.single.steps, 900);
    });

    test('an empty read folds to nothing', () {
      expect(HealthConnectReader.foldPoints([]), isEmpty);
    });
  });

  group('fromRow', () {
    test('marks a typed day as manual', () async {
      await storeManual(_monday, 12000);
      final row = await db.trackingDao.activityFor(_monday);

      expect(ActivitySync.fromRow(row!).isManual, isTrue);
    });
  });
}
