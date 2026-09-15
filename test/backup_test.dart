import 'dart:io';

import 'package:cal_tracker/data/backup/backup_service.dart';
import 'package:cal_tracker/data/backup/snapshot.dart';
import 'package:cal_tracker/data/backup/storage_access.dart';
import 'package:cal_tracker/data/database.dart';
import 'package:cal_tracker/data/tables.dart';
import 'package:cal_tracker/domain/day.dart';
import 'package:cal_tracker/domain/energy.dart';
import 'package:cal_tracker/domain/portion.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _monday = Day(20260914);
const _now = '2026-09-15T10:00:00.000';

/// Refuses access, to exercise the ungranted path.
class _NoAccess implements StorageAccess {
  @override
  Future<bool> hasAccess() async => false;

  @override
  Future<void> requestAccess() async {}
}

void main() {
  late AppDatabase db;
  late Directory folder;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folder = Directory.systemTemp.createTempSync('witcher_backup_test');
  });

  tearDown(() async {
    await db.close();
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });

  BackupService serviceWith({StorageAccess? access}) => BackupService(
        db: db,
        access: access ?? const AlwaysGrantedStorageAccess(),
        directory: folder.path,
      );

  /// A small but complete life: profile, food, meals, movement, a closed week.
  Future<void> seed() async {
    await withClock(
      Clock.fixed(_monday.toDateTime().add(const Duration(hours: 8))),
      () => db.profileDao.create(
        sex: Sex.male,
        birthYear: 1992,
        heightCm: 180,
        weightKg: 82,
        activityLevel: ActivityLevel.villageWalker,
        goal: Goal.loseFat,
      ),
    );

    final food = await db.foodsDao.upsert(
      FoodsCompanion.insert(
        name: 'Rye bread',
        searchKey: 'rye bread',
        kcal: 259,
        proteinG: const Value(9),
        source: FoodSource.seed,
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    for (var i = 0; i < 3; i++) {
      await db.journalDao.add(
        EntriesCompanion.insert(
          foodId: food,
          day: _monday.addDays(i),
          mealSlot: MealSlot.lunch,
          quantity: 80,
          unit: PortionUnit.grams,
          grams: 80,
          createdAt: _now,
        ),
      );
    }

    await db.trackingDao.upsertActivity(
      ActivityDaysCompanion.insert(
        day: _monday,
        steps: const Value(8200),
        distanceM: const Value(6100),
        source: ActivitySource.healthConnect,
        updatedAt: _now,
      ),
    );

    await db.weeksDao.upsert(
      WeeksCompanion.insert(
        weekStart: _monday,
        weekEnd: _monday.addDays(6),
        createdAt: _now,
      ),
    );
    await db.weeksDao.seal(
      _monday,
      summaryJson: '{"loggedDays":3}',
      narrative: 'Three days on the road.',
      xpAwarded: 60,
    );
  }

  group('taking a snapshot', () {
    test('carries every table', () async {
      await seed();

      final taken = await serviceWith().snapshot();

      expect(taken.version, BackupSnapshot.currentVersion);
      expect(taken.rowsIn('profiles'), 1);
      expect(taken.rowsIn('foods'), 1);
      expect(taken.rowsIn('entries'), 3);
      expect(taken.rowsIn('activity_days'), 1);
      expect(taken.rowsIn('weights'), 1);
      expect(taken.rowsIn('weeks'), 1);
    });

    test('an empty database snapshots to nothing', () async {
      expect((await serviceWith().snapshot()).isEmpty, isTrue);
    });
  });

  group('the round trip', () {
    test('everything comes back', () async {
      await seed();

      final service = serviceWith();
      final written = await service.writeMirror();
      expect(written.ok, isTrue, reason: written.message);

      // Wipe the world.
      await db.delete(db.entries).go();
      await db.delete(db.foods).go();
      await db.delete(db.profiles).go();
      expect(await db.foodsDao.count(), 0);

      final restored = await service.restoreFromMirror();
      expect(restored.ok, isTrue, reason: restored.message);

      expect(await db.foodsDao.count(), 1);
      expect(await db.journalDao.forDay(_monday), hasLength(1));
      expect(await db.profileDao.get(), isNotNull);

      final week = await db.weeksDao.forWeekStart(_monday);
      expect(week!.narrative, 'Three days on the road.');
      expect(week.xpAwarded, 60);
    });

    test('a restore replaces rather than merges', () async {
      await seed();
      final service = serviceWith();
      await service.writeMirror();

      // Something logged after the backup must not survive it.
      final food = (await db.foodsDao.search('Rye')).single;
      await db.journalDao.add(
        EntriesCompanion.insert(
          foodId: food.id,
          day: _monday.addDays(5),
          mealSlot: MealSlot.dinner,
          quantity: 200,
          unit: PortionUnit.grams,
          grams: 200,
          createdAt: _now,
        ),
      );

      await service.restoreFromMirror();

      expect(await db.journalDao.forDay(_monday.addDays(5)), isEmpty);
    });

    test('day-keyed values survive their converter', () async {
      // Days are stored as yyyymmdd integers and read back through a
      // TypeConverter; a backup that lost that would silently move every meal
      // to another week, which is the one thing that would corrupt the
      // product. See `Day`.
      await seed();
      final service = serviceWith();
      await service.writeMirror();
      await db.delete(db.entries).go();

      await service.restoreFromMirror();

      final items = await db.journalDao.forDay(_monday.addDays(2));
      expect(items, hasLength(1));
      expect(items.single.entry.day, _monday.addDays(2));
    });

    test('enum columns survive', () async {
      await seed();
      final service = serviceWith();
      await service.writeMirror();
      await db.delete(db.activityDays).go();

      await service.restoreFromMirror();

      final activity = await db.trackingDao.activityFor(_monday);
      expect(activity!.source, ActivitySource.healthConnect);
      expect(activity.steps, 8200);
    });
  });

  group('the files', () {
    test('writes both, and the Markdown is readable', () async {
      await seed();
      final service = serviceWith();

      await service.writeMirror();

      expect(service.jsonFile.existsSync(), isTrue);
      expect(service.markdownFile.existsSync(), isTrue);

      final markdown = await service.markdownFile.readAsString();
      expect(markdown, contains("The Witcher's Diet"));
      expect(markdown, contains('| entries | 3 |'));
      expect(markdown, contains('Three days on the road.'));
      // The reader has to know which file actually restores.
      expect(markdown, contains(BackupService.jsonName));
    });

    test('leaves no part file behind', () async {
      // The JSON is written to a temporary name and renamed, so a backup is
      // never left half-written.
      await seed();
      await serviceWith().writeMirror();

      final leftovers = folder
          .listSync()
          .map((e) => basenameOf(e.path))
          .where((name) => name.endsWith('.part'));

      expect(leftovers, isEmpty);
    });

    test('creates the folder if it is not there', () async {
      final missing = joinPath(folder.path, 'deeper', 'still');
      final service = BackupService(
        db: db,
        access: const AlwaysGrantedStorageAccess(),
        directory: missing,
      );

      await seed();
      final outcome = await service.writeMirror();

      expect(outcome.ok, isTrue, reason: outcome.message);
      expect(Directory(missing).existsSync(), isTrue);
    });

    test('overwrites a previous backup rather than appending', () async {
      await seed();
      final service = serviceWith();

      await service.writeMirror();
      await service.writeMirror();

      final decoded =
          BackupSnapshot.decode(await service.jsonFile.readAsString())!;
      expect(decoded.rowsIn('entries'), 3);
    });
  });

  group('when it cannot be done', () {
    test('says so when storage access is refused', () async {
      await seed();
      final service = serviceWith(access: _NoAccess());

      final outcome = await service.writeMirror();

      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('access'));
      expect(service.jsonFile.existsSync(), isFalse);
    });

    test('says so when there is no backup to restore', () async {
      final outcome = await serviceWith().restoreFromMirror();

      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('No backup found'));
    });

    test('refuses a backup from a newer version of the app', () async {
      // Loading it could silently drop a column the user's data lives in.
      final future = BackupSnapshot(
        version: BackupSnapshot.currentVersion + 1,
        takenAt: DateTime(2027),
        tables: const {
          'foods': [<String, dynamic>{'id': 1}],
        },
      );

      final outcome = await serviceWith().restore(future);

      expect(outcome.ok, isFalse);
      expect(outcome.message, contains('newer version'));
    });

    test('refuses an empty backup', () async {
      await seed();
      final before = await db.foodsDao.count();

      final outcome = await serviceWith().restore(
        BackupSnapshot(
          version: 1,
          takenAt: DateTime(2026),
          tables: const {'foods': []},
        ),
      );

      expect(outcome.ok, isFalse);
      // And nothing was wiped on the way to finding out.
      expect(await db.foodsDao.count(), before);
    });

    test('an unreadable file decodes to nothing rather than throwing',
        () async {
      await serviceWith().jsonFile.create(recursive: true);
      await serviceWith().jsonFile.writeAsString('not json at all');

      expect(await serviceWith().findExisting(), isNull);
    });
  });

  group('first launch', () {
    test('a database with no profile is fresh', () async {
      expect(await serviceWith().isFresh, isTrue);
    });

    test('a database with a profile is not', () async {
      await seed();
      expect(await serviceWith().isFresh, isFalse);
    });
  });

  group('the snapshot format', () {
    test('survives its own encoding', () {
      final taken = BackupSnapshot(
        version: 1,
        takenAt: DateTime(2026, 9, 15, 10, 30),
        tables: const {
          'foods': [
            {'id': 1, 'name': 'Rye bread', 'kcal': 259.0},
          ],
        },
      );

      final back = BackupSnapshot.decode(taken.encode())!;

      expect(back.version, 1);
      expect(back.takenAt, DateTime(2026, 9, 15, 10, 30));
      expect(back.tables['foods']!.single['name'], 'Rye bread');
    });

    test('restores parents before children', () {
      // `entries` references `foods`. Getting this order wrong produces a
      // foreign-key failure halfway through, with the database half-written.
      const order = BackupSnapshot.tableOrder;

      expect(order.indexOf('foods'), lessThan(order.indexOf('entries')));
      expect(order.indexOf('weeks'), lessThan(order.indexOf('achievements')));
    });

    test('decoding junk gives null, not an exception', () {
      expect(BackupSnapshot.decode('{}'), isNull);
      expect(BackupSnapshot.decode('[]'), isNull);
      expect(BackupSnapshot.decode('nonsense'), isNull);
      expect(BackupSnapshot.decode('{"tables": 3}'), isNull);
    });
  });
}

String basenameOf(String path) => path.split(Platform.pathSeparator).last;

String joinPath(String a, String b, String c) =>
    [a, b, c].join(Platform.pathSeparator);
